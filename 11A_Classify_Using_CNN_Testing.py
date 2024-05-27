import copy
import glob
from keras import layers
from keras.models import Model
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

def run_model(image_size, include_class_weighting, early_stopping, random_rotation, dropout, transfer_learning_model, fine_tuning):
    output_metrics_folder = "CNN_Metrics_final"
    output_models_folder = "CNN_Models_final"

    os.makedirs(output_metrics_folder, exist_ok=True)
    os.makedirs(output_models_folder, exist_ok=True)

    out_predictions_file_path = os.path.join(output_metrics_folder, "predictions.tsv")
    out_metrics_file_path = os.path.join(output_metrics_folder, "metrics.tsv")
    out_epoch_metrics_file_path = os.path.join(output_metrics_folder, "epoch_metrics.tsv")
    out_model_file_path = os.path.join(output_models_folder, "model.h5")

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
    test_image_file_paths = test_ds.file_paths
    test_classes = np.concatenate([y for x, y in test_ds], axis=0)
    test_labels = [test_ds.class_names[x] for x in test_classes]
    # 0 = friendly, 1 = unfriendly

    initial_bias = None # This will be set to 1 or to the class_weight.

    if include_class_weighting:
        # Apply class weights
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
        initial_bias = np.log([class_weight[1] / class_weight[0]])

        # Sets class weights. 0 = Friendly. 1 = Unfriendly.
        class_weight[0] = (1/class_weight[0]) * (total/2)
        class_weight[1] = (1/class_weight[1]) * (total/2)
    else:
        initial_bias=1

    data_augmentation = keras.Sequential(
        [
            layers.RandomFlip("horizontal", seed=123),
            layers.RandomRotation(random_rotation, seed=123),
        ]
    )

    model_function = make_model
    base_model = None

    if transfer_learning_model == "MobileNetV2":
        model_function = make_model_mobile_net2
        base_model = MobileNetV2(input_shape=image_size + (3,), include_top=False, weights='imagenet')
        base_model.trainable = False
    elif transfer_learning_model == "ResNet50":
        model_function = make_model_resnet_50
        base_model = ResNet50(input_shape=image_size + (3,), include_top=False, weights='imagenet')
        base_model.trainable = False

    model = model_function(input_shape=image_size + (3,), output_bias=initial_bias, data_augmentation=data_augmentation, base_model=base_model, dropout=dropout)
    #model.summary() # Print a summary of the model onto the command line.

    if early_stopping:
        #keras.callbacks.ModelCheckpoint(os.path.join(output_models_folder, "checkpoint_{epoch}.h5")),
        callbacks = [
            keras.callbacks.EarlyStopping(
              monitor='val_auc', # Stops when validation AUC is the highest.
              verbose=1,
              patience=10,
              mode='max',
              restore_best_weights=True)
        ]
    else:
        callbacks = []

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

    train_the_model_count = 1
    if transfer_learning_model and fine_tuning:
        train_the_model_count = 2

    for i in range(train_the_model_count):
        if i == 0:
            learning_rate = 0.001
            epoch_count = 30

        if i == 1:
            base_model.trainable = True
            learning_rate = 0.00001 # Lower the learning rate significantly because the base model is far bigger than our model.
            epoch_count = 15

        model.compile(
            optimizer=keras.optimizers.Adam(learning_rate),
            loss="binary_crossentropy",
            metrics=METRICS,
        )

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

        historyDf = pd.DataFrame.from_dict(history.history)
        historyDf.to_csv(out_epoch_metrics_file_path, sep="\t")

        results = model.evaluate(test_ds)

        with open(out_metrics_file_path, "w") as metrics_file:
            metrics_file.write("metric\tvalue\n")

            for name, value in zip(model.metrics_names, results):
                metrics_file.write(f"{name}\t{value}\n")

        predictions = model.predict(test_ds)

        with open(out_predictions_file_path, "w") as pred_file:
            pred_file.write("image_file_path\tlabel\tprobability_unfriendly\n")

            for i in range(len(predictions)):
                out_row = f"{test_image_file_paths[i]}\t{test_labels[i]}\t{predictions[i][0]}\n"
                pred_file.write(out_row)

        if i==1 and fine_tuning and transfer_learning_model:
            base_model.trainable = False
            model = freeze_layers(model)

        model.save(out_model_file_path)

def make_model(input_shape, output_bias, data_augmentation, base_model, dropout=0.3):
    if output_bias is not None:
        output_bias = tf.keras.initializers.Constant(output_bias)

    inputs = keras.Input(shape=input_shape)

    x = data_augmentation(inputs)
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
        output_bias = tf.keras.initializers.Constant(output_bias) # Use the initial_bias as defined above. Decreases initial loss.
    inputs = keras.Input(shape=input_shape)

    x = data_augmentation(inputs)
    x = tf.keras.applications.mobilenet_v2.preprocess_input(x)
    x = base_model(x, training=False)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(dropout)(x)

    outputs = layers.Dense(1, activation="sigmoid", bias_initializer=output_bias)(x)
    return keras.Model(inputs, outputs)

def make_model_resnet_50(input_shape, output_bias, data_augmentation, base_model, dropout=0.3):
    output_bias = tf.keras.initializers.Constant(output_bias)

    inputs = keras.Input(shape=input_shape)

    x = data_augmentation(inputs)
    x = tf.keras.applications.resnet.preprocess_input(x)
    x = base_model(x, training=False)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(dropout)(x)

    outputs = layers.Dense(1, activation="sigmoid", bias_initializer=output_bias)(x)
    return keras.Model(inputs, outputs)

def freeze_layers(model):
    for i in model.layers:
        i.trainable = False
        if isinstance(i, Model):
            freeze_layers(i)
    return model

def use_available_image_version(file_paths):
    results = []

    for x in file_paths:
        first_dir = x.split("/")[0]
        second_dir = x.split("/")[1]
        second_dir = "-".join(second_dir.split("-")[:-1])
        file_name = x.split("/")[2]

        mod_x = f"{first_dir}/{second_dir}-v*/{file_name}"
        file_path_to_use = sorted(glob.glob(mod_x))[0]

        results.append(file_path_to_use)

    return results

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
        destination_file_path = f"{destination_directory}/{os.path.basename(os.path.dirname(file_path))}.jpg"
        shutil.copy(file_path, destination_file_path)

        if os.path.exists(destination_file_path):
            count += 1

    print(f"{count} images in {destination_directory}")

random_seed = 123
seed(random_seed) #Set random seed for numpy
tf.random.set_seed(random_seed) #Set random seed for tensorflow

training_df = pd.read_csv("Image_Metrics_Classification_Data.tsv", delimiter="\t")
testing_df = pd.read_csv("Image_Metrics_Classification_Data_Testing.tsv", delimiter="\t")

training_image_file_paths_unfriendly = []
training_image_file_paths_friendly = []

image_file_path_key = "image_file_path"

for index, row in training_df.iterrows():
    if row["Class"] == 0:
        training_image_file_paths_unfriendly.append(row[image_file_path_key])
    else:
        training_image_file_paths_friendly.append(row[image_file_path_key])


testing_image_file_paths_unfriendly = []
testing_image_file_paths_friendly = []

for index, row in testing_df.iterrows():
    if row["Class"] == 0:
        testing_image_file_paths_unfriendly.append(row[image_file_path_key])
    else:
        testing_image_file_paths_friendly.append(row[image_file_path_key])

training_image_file_paths_friendly = use_available_image_version(training_image_file_paths_friendly)
training_image_file_paths_unfriendly = use_available_image_version(training_image_file_paths_unfriendly)
testing_image_file_paths_friendly = use_available_image_version(testing_image_file_paths_friendly)
testing_image_file_paths_unfriendly = use_available_image_version(testing_image_file_paths_unfriendly)

copy_images_to_directory(training_image_file_paths_friendly, "TrainingImages/friendly")
copy_images_to_directory(training_image_file_paths_unfriendly, "TrainingImages/unfriendly")
copy_images_to_directory(testing_image_file_paths_friendly, "TestingImages/friendly")
copy_images_to_directory(testing_image_file_paths_unfriendly, "TestingImages/unfriendly")

model_settings = {
    "image_size": 224,
    "include_class_weighting": True,
    "early_stopping": True,
    "random_rotation": 0.2,
    "dropout": 0.5,
    "transfer_learning_model": "ResNet50",
    "fine_tuning": True
}

run_model(**model_settings)
