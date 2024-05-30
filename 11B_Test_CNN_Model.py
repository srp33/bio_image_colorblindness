import copy
import glob
from keras.models import load_model
import numpy as np
from numpy.random import seed
import os
import pandas as pd
import shutil
import sys
import tensorflow as tf

def use_available_image_version(file_paths):
    results = []

    for x in file_paths:
        # It will only do this for eLife images.
        if x.startswith("ImageSample"):
            first_dir = x.split("/")[0]
            second_dir = x.split("/")[1]
            second_dir = "-".join(second_dir.split("-")[:-1])
            file_name = x.split("/")[2]

            mod_x = f"{first_dir}/{second_dir}-v*/{file_name}"
            file_path_to_use = sorted(glob.glob(mod_x))[0]

            results.append(file_path_to_use)
        else:
            results.append(x)

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

models_dir_path = sys.argv[1]
testing_images_tsv_file_path = sys.argv[2]
out_dir_path = sys.argv[3]

model_file_path = os.path.join(models_dir_path, "model.h5")
out_predictions_file_path = os.path.join(out_dir_path, "predictions.tsv")
out_metrics_file_path = os.path.join(out_dir_path, "metrics.tsv")

if not os.path.exists(model_file_path):
    print(f"A model file must exist at {model_file_path}")
    sys.exit(1)

model = load_model(model_file_path)

os.makedirs(out_dir_path, exist_ok=True)

random_seed = 123
seed(random_seed) #Set random seed for numpy
tf.random.set_seed(random_seed) #Set random seed for tensorflow

image_file_path_key = "image_file_path"

testing_df = pd.read_csv(testing_images_tsv_file_path, delimiter="\t")
testing_image_file_paths_unfriendly = []
testing_image_file_paths_friendly = []

for index, row in testing_df.iterrows():
    if row["Class"] == 0:
        testing_image_file_paths_unfriendly.append(row[image_file_path_key])
    else:
        testing_image_file_paths_friendly.append(row[image_file_path_key])

testing_image_file_paths_friendly = use_available_image_version(testing_image_file_paths_friendly)
testing_image_file_paths_unfriendly = use_available_image_version(testing_image_file_paths_unfriendly)

copy_images_to_directory(testing_image_file_paths_friendly, "TestingImages/friendly")
copy_images_to_directory(testing_image_file_paths_unfriendly, "TestingImages/unfriendly")

image_size = (224, 224)

test_ds = tf.keras.preprocessing.image_dataset_from_directory(
    "TestingImages/",
    image_size=image_size,
    shuffle=False
)

test_image_file_paths = test_ds.file_paths
test_classes = np.concatenate([y for x, y in test_ds], axis=0)
test_labels = [test_ds.class_names[x] for x in test_classes]
# 0 = friendly, 1 = unfriendly

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
