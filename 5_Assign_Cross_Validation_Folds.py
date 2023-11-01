import os
import pandas as pd
import random
from sklearn.model_selection import StratifiedKFold

in_file_path = "Image_Metrics_Classification_Data.tsv"
out_file_path = "Cross_Validation_Assignments.tsv"

n_cv_splits = 5
num_iterations = 3
seed = 33
random.seed(seed)

df = pd.read_csv(in_file_path, delimiter="\t")

## Make sure we don't have multiple versions of the same image.
#image_file_paths = ["-".join(os.path.basename(x).split("-")[:-1]) for x in df["image_file_path"].tolist()]
#print(len(image_file_paths))
#print(len(set(image_file_paths)))
#for x in image_file_paths:
#    if image_file_paths.count(x) > 1:
#        print(x)

y = df["Class"].values
X = df.drop("Class", axis=1)

with open(out_file_path, "w") as out_file:
    out_file.write("image_file_path\tdeut_image_file_path\titeration\tfold\tcohort\tClass\n")

    for iteration in range(1, num_iterations + 1):
        stratified_kfold = StratifiedKFold(n_splits=n_cv_splits, shuffle=True, random_state=iteration)

        fold = 0
        for train_indices, test_indices in stratified_kfold.split(X, y):
            fold += 1

            for row_index, image_file_path in enumerate(df["image_file_path"]):
                deut_image_file_path = df["deut_image_file_path"][row_index]
                cohort = ["testing", "training"][row_index in train_indices]
                Class = y[row_index]

                out_file.write(f"{image_file_path}\t{deut_image_file_path}\t{iteration}\t{fold}\t{cohort}\t{Class}\n")
