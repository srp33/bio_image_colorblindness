import sklearn as sk
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score
from sklearn.neighbors import KNeighborsClassifier
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
import pandas as pd
import numpy as np

out_file_path = "Cross_Validation_Results_Metrics.tsv"

metrics_df = pd.read_csv("Image_Metrics_Classification_Data.tsv", delimiter="\t")
assignments_df = pd.read_csv("Cross_Validation_Assignments.tsv", delimiter="\t")

def train_test(model, training_X, training_y, testing_X, testing_y):
    model.fit(training_X, training_y)
    predictions = model.predict_proba(testing_X)

    return roc_auc_score(testing_y, predictions[:,1])

with open(out_file_path, "w") as out_file:
    out_file.write("iteration\tfold\talgorithm\tauroc\n")

    for iteration in sorted(set(assignments_df["iteration"])):
        for fold in sorted(set(assignments_df["fold"])):
            print(iteration, fold)

            training_image_file_paths = assignments_df.loc[(assignments_df['iteration'] == iteration) & (assignments_df['fold'] == fold) & (assignments_df['cohort'] == "training")]["image_file_path"]
            testing_image_file_paths = assignments_df.loc[(assignments_df['iteration'] == iteration) & (assignments_df['fold'] == fold) & (assignments_df['cohort'] == "testing")]["image_file_path"]

            training_df = metrics_df[metrics_df["image_file_path"].isin(training_image_file_paths)]
            testing_df = metrics_df[metrics_df["image_file_path"].isin(testing_image_file_paths)]

            training_df = training_df.drop("image_file_path", axis=1)
            testing_df = testing_df.drop("image_file_path", axis=1)
            training_df = training_df.drop("deut_image_file_path", axis=1)
            testing_df = testing_df.drop("deut_image_file_path", axis=1)

            training_y = training_df["Class"].values
            training_X = training_df.drop("Class", axis=1)
            testing_y = testing_df["Class"].values
            testing_X = testing_df.drop("Class", axis=1)

            columns_to_scale = ["max_ratio", "num_high_ratios", "proportion_high_ratio_pixels", "mean_delta", "euclidean_distance_metric"]
            pipeline = ColumnTransformer([("scaler", StandardScaler(), columns_to_scale)])
            training_X = pipeline.fit_transform(training_X)
            testing_X = pipeline.transform(testing_X)

            rf_auroc = train_test(RandomForestClassifier(class_weight="balanced", random_state=iteration*fold), training_X, training_y, testing_X, testing_y)
            knn_auroc = train_test(KNeighborsClassifier(), training_X, training_y, testing_X, testing_y)
            lr_auroc = train_test(LogisticRegression(solver='liblinear', class_weight="balanced", random_state=iteration*fold), training_X, training_y, testing_X, testing_y)

            out_file.write(f"{iteration}\t{fold}\tRandom Forests\t{rf_auroc}\n")
            out_file.write(f"{iteration}\t{fold}\tNearest Neighbors\t{knn_auroc}\n")
            out_file.write(f"{iteration}\t{fold}\tLogistic Regression\t{lr_auroc}\n")
