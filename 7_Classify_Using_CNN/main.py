import glob
from keras import layers
from keras.models import Model
import matplotlib.pyplot as plt
import numpy as np
from numpy.random import seed
import os
import pandas as pd
import shutil
import sys
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.applications import ResNet50

def make_model(input_shape, output_bias, data_augmentation, base_model, dropout=0.3):
    if output_bias is not None:
        output_bias = tf.keras.initializers.Constant(output_bias)

    inputs = keras.Input(shape=input_shape)

    x = data_augmentation(inputs) #apply augmentation
    x = layers.Rescaling(1./255)(x)

    # Entry block
    x = layers.Conv2D(32, 3, strides=2, padding="same")(x)
    x = layers.BatchNormalization()(x)
    x = layers.Activation("relu")(x)

    x = layers.Conv2D(64, 3, padding="same")(x)
    x = layers.BatchNormalization()(x)
    x = layers.Activation("relu")(x)

    previous_block_activation = x  # Set aside residual

    for size in [128, 256, 512, 728]:
        x = layers.Activation("relu")(x)
        x = layers.SeparableConv2D(size, 3, padding="same")(x)
        x = layers.BatchNormalization()(x)

        x = layers.Activation("relu")(x)
        x = layers.SeparableConv2D(size, 3, padding="same")(x)
        x = layers.BatchNormalization()(x)

        x = layers.MaxPooling2D(3, strides=2, padding="same")(x)

        # Project residual
        residual = layers.Conv2D(size, 1, strides=2, padding="same")(
            previous_block_activation
        )
        x = layers.add([x, residual])  # Add back residual
        previous_block_activation = x  # Set aside next residual

    x = layers.SeparableConv2D(1024, 3, padding="same")(x)
    x = layers.BatchNormalization()(x)
    x = layers.Activation("relu")(x)

    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(dropout)(x) #Reduce overfitting

    outputs = layers.Dense(1, activation="sigmoid")(x)

    return keras.Model(inputs, outputs)

def make_model_mobile_net2(input_shape, output_bias, data_augmentation,base_model, dropout=0.3):
    if output_bias is not None:
        output_bias = tf.keras.initializers.Constant(output_bias) #Use the initial_bias as defined above. Decreases initial loss.
    inputs = keras.Input(shape=input_shape)

    x = data_augmentation(inputs) #apply augmentation
    x = tf.keras.applications.mobilenet_v2.preprocess_input(x)
    x = base_model(x, training=False) #Call our MobileNetV2 base_model.
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(dropout)(x) #Used to decrease overfitting

    outputs = layers.Dense(1, activation="sigmoid", bias_initializer=output_bias)(x)
    return keras.Model(inputs, outputs)

def make_model_mobile_net2_no_preprocess(input_shape, output_bias, data_augmentation,base_model, dropout=0.3):
    if output_bias is not None:
        output_bias = tf.keras.initializers.Constant(output_bias) #Use the initial_bias as defined above. Decreases initial loss.
    inputs = keras.Input(shape=input_shape)

    x = data_augmentation(inputs) #apply augmentation
    x = base_model(x, training=False) #Call our MobileNetV2 base_model.
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(dropout)(x) #Used to decrease overfitting

    outputs = layers.Dense(1, activation="sigmoid", bias_initializer=output_bias)(x)
    return keras.Model(inputs, outputs)

def make_model_resnet_50(input_shape, output_bias, data_augmentation, base_model, dropout=0.3):
    output_bias = tf.keras.initializers.Constant(output_bias)

    inputs = keras.Input(shape=input_shape)

    x = data_augmentation(inputs) #apply augmentation
    x = tf.keras.applications.resnet.preprocess_input(x)
    x = base_model(x, training=False)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(dropout)(x) #Lowered dropout rate from 0.5 to 0.3.

    outputs = layers.Dense(1, activation="sigmoid",bias_initializer=output_bias)(x)
    return keras.Model(inputs, outputs)

def freeze_layers(model):
    for i in model.layers:
        i.trainable = False
        if isinstance(i, Model):
            freeze_layers(i)
    return model

def run_model(model_function = make_model_mobile_net2,
              output_folder = "SavedModel",
              image_size=224,
              include_class_weighting=False,
              early_stopping=False,
              random_rotation = 0.2,
              dropout=0.3,
              epoch_count=30,
              transfer_learning=False,
              transfer_learning_model="",
              fine_tuning=False):

    image_size = (image_size, image_size)
    batch_size = 32
    validation_split = 0.20

    train_ds = tf.keras.preprocessing.image_dataset_from_directory(
        "TrainingImages/",
        validation_split=validation_split,
        labels='inferred',
        label_mode='binary',
        subset="training",
        seed=random_seed,
        image_size=image_size,
        batch_size=batch_size,
    )

    val_ds = tf.keras.preprocessing.image_dataset_from_directory(
        "TrainingImages/",
        validation_split=validation_split,
        labels='inferred',
        label_mode='binary',
        subset="validation",
        seed=random_seed,
        image_size=image_size,
        batch_size=batch_size,
    )

    test_ds = tf.keras.preprocessing.image_dataset_from_directory(
        "TestingImages/",
        image_size=image_size,
        shuffle=False
    )

    # Retrieve labels from our test_ds. Used later.
    test_labels = np.concatenate([y for x, y in test_ds], axis=0)

    initial_bias = None # This will be set to 1 or the class_weight

    if include_class_weighting:
        # Apply weights
        class_weight = {0:0, 1:0}
        y = np.concatenate([y for x, y in train_ds], axis=0)
        total = 0

        for i in y:
            if int(i[0]) in class_weight:
                class_weight[int(i[0])]+=1
                total+=1
            else:
                print("Error:", i)

        # Sets intial_bias to be used while training the model. Decreases loss during the first few epochs.
        initial_bias = np.log([class_weight[1]/class_weight[0]])
        print("Initial Bias: ", initial_bias)
        # Sets class weights. 0 = Friendly. 1 = Unfriendly. We have unbalanced classes, so this is needed to give more accurate results.
        class_weight[0]=(1/class_weight[0])*(total/2)
        class_weight[1]=(1/class_weight[1])*(total/2)
    else:
        initial_bias=1

    data_augmentation = keras.Sequential(
        [
            layers.RandomFlip("horizontal", seed=123),
            layers.RandomRotation(random_rotation, seed = 123),
        ]
    )

    base_model = None

    if transfer_learning:
        if transfer_learning_model =="MobileNetV2":

            base_model = MobileNetV2(input_shape=image_size+(3,),
            include_top=False,
            weights='imagenet')

            base_model.trainable = False

        elif transfer_learning_model =="ResNet50":
            base_model = ResNet50(weights='imagenet',
                             input_shape= image_size+(3,),
                             include_top=False)

            base_model.trainable = False


    model = model_function(input_shape=image_size+ (3,), output_bias=initial_bias, data_augmentation=data_augmentation, base_model=base_model, dropout=dropout)

    model.summary() # Print a summary of the model onto the command line.

    if early_stopping:
        callbacks = [
            keras.callbacks.ModelCheckpoint(os.path.join(output_folder,"save_at_{epoch}.h5")),
            keras.callbacks.EarlyStopping(
            monitor='val_auc', # Stops when validation AUC is the highest.
            verbose=1,
            patience=10,
            mode='max',
            restore_best_weights=True)
        ]
    else:
        callbacks = [
            keras.callbacks.ModelCheckpoint(os.path.join(output_folder,"save_at_{epoch}.h5")),
        ]

    METRICS = [
        keras.metrics.TruePositives(name='tp'),
        keras.metrics.FalsePositives(name='fp'),
        keras.metrics.TrueNegatives(name='tn'),
        keras.metrics.FalseNegatives(name='fn'),
        keras.metrics.BinaryAccuracy(name='accuracy'),
        keras.metrics.Precision(name='precision'),
        keras.metrics.Recall(name='recall'),
        keras.metrics.AUC(name='auc'),
        keras.metrics.AUC(name='prc', curve='PR'), # Precision-recall curve
    ]

    model.compile(
        optimizer=keras.optimizers.Adam(1e-3),
        loss="binary_crossentropy",
        metrics=METRICS,
    )

    # Fit the model. Use defined class weights to improve accuracy.
    if include_class_weighting:
        history = model.fit(
            train_ds,
            epochs=epoch_count,
            callbacks=callbacks,
            validation_data=val_ds,
            class_weight=class_weight
        )
    else:
        history = model.fit(
            train_ds,
            epochs=epoch_count,
            callbacks=callbacks,
            validation_data=val_ds,
        )


    print(history.history.keys())

    historyDf = pd.DataFrame.from_dict(history.history)
    historyDf.to_csv(os.path.join(output_folder, "history_epochs.tsv"), sep="\t")

    with open(os.path.join(output_folder, "metrics.tsv"), "w") as file:
        results = model.evaluate(test_ds)
        for name, value in zip(model.metrics_names, results):
            file.write(str(name)+': '+str(value)+"\n")

    model.save(os.path.join(output_folder, "model.h5"))

    predictions = model.predict(test_ds)

    with open(os.path.join(output_folder, "predictions.tsv"), "w") as output:
        for i in range(len(predictions)):
            if test_labels[i]==1:
                output.write(f"Unfriendly\t{float(predictions[i])}\n")
            else:
                output.write(f"Friendly\t{float(predictions[i])}\n")

    if fine_tuning and transfer_learning:
        # Fine tune the model by setting the base_model as trainable.
        base_model.trainable = True

        # Lower the learning rate significantly since the base model is far bigger than our model.
        model.compile(optimizer=keras.optimizers.Adam(1e-5),
                    loss="binary_crossentropy",
                    metrics=METRICS)

        new_callbacks = [
            keras.callbacks.EarlyStopping(
            verbose=1,
            patience=10,
            restore_best_weights=True)
        ]

        if include_class_weighting:
            history1 = model.fit(
                train_ds,
                epochs=epoch_count,
                callbacks=new_callbacks,
                validation_data=val_ds,
                class_weight=class_weight
            )
        else:
            history1 = model.fit(
                train_ds,
                epochs=epoch_count,
                callbacks=new_callbacks,
                validation_data=val_ds,
            )

        print(history1.history.keys())

        historyDf1 = pd.DataFrame.from_dict(history1.history)
        historyDf1.to_csv(os.path.join(output_folder,"History_FineTuning.tsv"), sep="\t")

        # Freeze all layers of our model so that we can save it.
        base_model.trainable = False

        model_freezed = freeze_layers(model)

        model_freezed.save(os.path.join(output_folder,"finetuning_save.h5"))

        with open(os.path.join(output_folder,"Evaluated_Finetuning"), "w") as file:
            results = model_freezed.evaluate(test_ds)
            for name, value in zip(model_freezed.metrics_names, results):
                file.write(str(name)+': '+str(value)+"\n")

        predictions_finetuned = model_freezed.predict(test_ds)

        with open(os.path.join(output_folder,"Predictions_Finetuning"),"w") as output:
            for i in range(len(predictions_finetuned)):
                if test_labels[i]==1:
                    output.write(f"Unfriendly\t{float(predictions_finetuned[i])}\n")
                else:
                    output.write(f"Friendly\t{float(predictions_finetuned[i])}\n")
    else:
        print("No fine-tuning performed.")

def copy_images_to_directory(file_paths, destination_directory):
    # Create the destination directory if it does not exist
    os.makedirs(destination_directory, exist_ok = True)

    # Clear the destination directory if it already exists
    for file_path in glob.glob(f"{destination_directory}/*"):
        if os.path.isfile(file_path):
            os.unlink(file_path)

    # Copy the files to the destination directory
    count = 0
    for file_path in file_paths:
        shutil.copy(file_path, destination_directory)
        #if not os.path.exists(f"{destination_directory}/{os.path.basename(file_path)}"):
        if os.path.exists(f"{destination_directory}/{os.path.basename(file_path)}"):
            count += 1

    print(f"{count} images in {destination_directory}")

random_seed = 123
seed(random_seed) #Set random seed for numpy
tf.random.set_seed(random_seed) #Set random seed for tensorflow

out_file_path = "Cross_Validation_Results_CNN.tsv"

assignments_df = pd.read_csv("Cross_Validation_Assignments.tsv", delimiter="\t")

with open(out_file_path, "w") as out_file:
    out_file.write("iteration\tfold\talgorithm\tauroc\n")

    for iteration in sorted(set(assignments_df["iteration"])):
        for fold in sorted(set(assignments_df["fold"])):
            print(iteration, fold)

            training_image_df = assignments_df.loc[(assignments_df['iteration'] == iteration) & (assignments_df['fold'] == fold) & (assignments_df['cohort'] == "training")]
            testing_image_df = assignments_df.loc[(assignments_df['iteration'] == iteration) & (assignments_df['fold'] == fold) & (assignments_df['cohort'] == "testing")]

            training_image_file_paths_unfriendly = []
            training_image_file_paths_friendly = []

            for index, row in training_image_df.iterrows():
                if row["Class"] == 0:
                    training_image_file_paths_unfriendly.append(row["image_file_path"])
                else:
                    training_image_file_paths_friendly.append(row["image_file_path"])

            testing_image_file_paths_unfriendly = []
            testing_image_file_paths_friendly = []

            for index, row in testing_image_df.iterrows():
                if row["Class"] == 0:
                    testing_image_file_paths_unfriendly.append(row["image_file_path"])
                else:
                    testing_image_file_paths_friendly.append(row["image_file_path"])

            copy_images_to_directory(training_image_file_paths_friendly, "TrainingImages/friendly")
            copy_images_to_directory(training_image_file_paths_unfriendly, "TrainingImages/unfriendly")
            copy_images_to_directory(testing_image_file_paths_friendly, "TestingImages/friendly")
            copy_images_to_directory(testing_image_file_paths_unfriendly, "TestingImages/unfriendly")

            #TODO: Modify the output_folder to take into account fold, iteration
            #TODO: Do we need to save the model after each epoch?
            #TODO: Update the code for predictions.tsv to save image_file_path and class labels.
            model_0 = {
                'model_function': make_model,
                'output_folder': "CNN_Models/0",
                'image_size': 180,
                'include_class_weighting': False,
                'early_stopping': False,
                'random_rotation': 0.2,
                'dropout': 0.3,
                'epoch_count': 3,
                'transfer_learning': False,
                'transfer_learning_model': None,
                'fine_tuning': False
            }

#            model_0 = {
#                'model_function': make_model,
#                'output_folder': "SavedModel_0",
#                'image_size': 180,
#                'include_class_weighting': False,
#                'early_stopping': False,
#                'random_rotation': 0.2,
#                'dropout': 0.3,
#                'epoch_count': 30,
#                'transfer_learning': False,
#                'transfer_learning_model': None,
#                'fine_tuning': False
#            }


            run_model(**model_0)

            break
        break

# run_model(
#     epoch_count = 2,
#     transfer_learning=True,
#     transfer_learning_model ="MobileNetV2",
#     fine_tuning = True
# )

#model_0 = {
#    'model_function': make_model,
#    'output_folder': "SavedModel_0",
#    'image_size': 180,
#    'include_class_weighting': False,
#    'early_stopping': False,
#    'random_rotation': 0.2,
#    'dropout': 0.3,
#    'epoch_count': 30,
#    'transfer_learning': False,
#    'transfer_learning_model': None,
#    'fine_tuning': False
#}

#run_model(**model_0)

#model1 = model0.copy()
#model1['include_class_weighting'] = True
#model1['output_folder'] = "SavedModel1"
#
#model2 = model1.copy()
#model2['early_stopping'] = True
#model2['output_folder'] = "SavedModel2"
#
#model3 = model2.copy()
#model3['random_rotation'] = 0.1
#model3['output_folder'] = "SavedModel3"
#
#model4 = model3.copy()
#model4['random_rotation'] = 0.2
#model4["model_function"] = make_model_resnet_50
#model4['transfer_learning'] =  True
#model4['transfer_learning_model'] = "ResNet50"
#model4['output_folder'] = "SavedModel4"
#
#model4_1 = model4.copy()
#model4_1["image_size"] = 224
#model4_1["fine_tuning"] = True
#model4_1['output_folder'] = "SavedModel4_1"
#
#model5 = model4_1.copy()
#model5["model_function"] = make_model_mobile_net2
#model5['transfer_learning_model'] = "MobileNetV2"
#model5['output_folder'] = "SavedModel5"
#
#model6 = model5.copy()
#model6["dropout"] = 0.2
#model6['output_folder'] = "SavedModel6"
#
##Sanity check
#model7 = model6.copy()
#model7['output_folder'] = "SavedModel7"
#
#model10 = model7.copy()
#model10["image_size"] = 512
#model10['output_folder'] = "SavedModel10"
#
#model11 = {
#    'model_function':make_model_mobile_net2_no_preprocess,
#    'output_folder':"SavedModel11",
#    'image_size':225,
#    'include_class_weighting':True,
#    'early_stopping':True,
#    'random_rotation':0.2,
#    'dropout':0.2,
#    'epoch_count':30,
#    'transfer_learning':True,
#    'transfer_learning_model':"MobileNetV2",
#    'fine_tuning':True
#}
#run_model(**model11)
#
#model12 = {
#    'model_function':make_model_mobile_net2_no_preprocess,
#    'output_folder':"SavedModel12",
#    'image_size':225,
#    'include_class_weighting':True,
#    'early_stopping':True,
#    'random_rotation':0.2,
#    'dropout':0.2,
#    'epoch_count':30,
#    'transfer_learning':True,
#    'transfer_learning_model':"MobileNetV2",
#    'fine_tuning':True
#}
#run_model(**model12)
