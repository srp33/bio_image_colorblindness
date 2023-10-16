import pandas as pd
import random
from sklearn.model_selection import StratifiedKFold

in_file_path = "Image_Metrics_Classification_Data.tsv"
out_file_path = "Cross_Validation_Assignments.tsv"

n_cv_splits = 10
num_iterations = 10
seed = 33
random.seed(seed)

df = pd.read_csv(in_file_path, delimiter="\t")

X = df.iloc[:,:-1]
y = df.iloc[:,-1]

with open(out_file_path, "w") as out_file:
    out_file.write("image_file_path\titeration\tfold\tcohort\n")

    for iteration in range(1, num_iterations + 1):
        stratified_kfold = StratifiedKFold(n_splits=n_cv_splits, shuffle=True, random_state=iteration)

        fold = 0
        for train_indices, test_indices in stratified_kfold.split(X, y):
            fold += 1

            for row_index, image_file_path in enumerate(df["image_file_path"]):
                cohort = ["testing", "training"][row_index in train_indices]
                out_file.write(f"{image_file_path}\t{iteration}\t{fold}\t{cohort}\n")
