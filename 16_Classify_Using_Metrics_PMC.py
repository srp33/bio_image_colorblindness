import sklearn as sk
from sklearn.compose import ColumnTransformer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, confusion_matrix, classification_report
from sklearn.metrics import precision_recall_curve, average_precision_score
from sklearn.metrics import precision_recall_fscore_support
from sklearn.metrics import roc_auc_score
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
import pandas as pd
import numpy as np

out_metrics_file_path = "PMC_Results_Metrics.tsv"
out_predictions_file_path = "PMC_Results_Predictions.tsv"

training_df = pd.read_csv("Image_Metrics_Classification_Data.tsv", delimiter="\t")
testing_df = pd.read_csv("Image_Metrics_Classification_Data_PMC.tsv", delimiter="\t")

training_df = training_df.drop("image_file_path", axis=1)
training_df = training_df.drop("deut_image_file_path", axis=1)

training_y = training_df["Class"].values
training_X = training_df.drop("Class", axis=1)
testing_y = testing_df["Class"].values
testing_X = testing_df.drop("Class", axis=1)

columns_to_scale = ["max_ratio", "num_high_ratios", "proportion_high_ratio_pixels", "mean_delta", "euclidean_distance_metric"]
pipeline = ColumnTransformer([("scaler", StandardScaler(), columns_to_scale)])
training_X = pipeline.fit_transform(training_X)
testing_X = pipeline.transform(testing_X)

model = LogisticRegression(solver='liblinear', class_weight="balanced", random_state=0)
model.fit(training_X, training_y)
predictions = model.predict_proba(testing_X)

auroc = roc_auc_score(testing_y, predictions[:,1])
auprc = average_precision_score(testing_y, predictions[:,1])

discrete_predictions = predictions[:,1] > 0.5

precision, recall, f1, support = precision_recall_fscore_support(testing_y, discrete_predictions)

accuracy = accuracy_score(testing_y, discrete_predictions)
tn, fp, fn, tp = confusion_matrix(testing_y, discrete_predictions).ravel()

with open(out_metrics_file_path, "w") as out_file:
    out_file.write(f"auroc\tauprc\tprecision\trecall\tf1\taccuracy\ttp\ttn\tfp\tfn\n{auroc}\t{auprc}\t{precision[1]}\t{recall[1]}\t{f1[1]}\t{accuracy}\t{tp}\t{tn}\t{fp}\t{fn}")

with open(out_predictions_file_path, "w") as out_file:
    out_file.write("label\tprobability_unfriendly\n")

    for i, label in enumerate(testing_y):
        prediction = predictions[i,1]
        out_file.write(f"{label}\t{prediction}\n")
