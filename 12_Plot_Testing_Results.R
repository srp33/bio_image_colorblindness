library(pROC)
library(PRROC)
library(tidyverse)
library(writexl)

source("Functions.R")

###########################################################
# This is for the predictions based on metrics.
###########################################################

predictions = read_tsv("Testing_Results_Predictions.tsv") %>%
  mutate(label = ifelse(label == 1, "Definitely problematic", "Definitely okay"))

plot_probabilities(predictions, "Metrics_Testing_Predictions")
plot_roc(predictions, "Metrics_Testing_ROC")
plot_prc(predictions, "Metrics_Testing_AUPRC")

results_summary = read_tsv("Testing_Results_Metrics.tsv") %>%
  pivot_longer(everything()) %>%
  dplyr::rename(Metric = name, Value = value) %>%
  clean_performance_metrics("eLife", "Logistic regression")

###########################################################
# This is for the predictions based on CNN.
###########################################################

predictions = read_tsv("CNN_Metrics_final/predictions.tsv") %>%
  mutate(label = ifelse(label == "friendly", "Definitely okay", "Definitely problematic"))

plot_probabilities(predictions, "CNN_Testing_predictions")
plot_roc(predictions, "CNN_Testing_ROC")
plot_prc(predictions, "CNN_Testing_AUPRC")

read_tsv("CNN_Metrics_final/metrics.tsv") %>%
  dplyr::rename(Metric = metric, Value = value) %>%
  filter(Metric != "loss") %>%
  mutate(Metric = ifelse(Metric == "auc", "AUROC", Metric)) %>%
  mutate(Metric = ifelse(Metric == "prc", "AUPRC", Metric)) %>%
  clean_performance_metrics("eLife", "Convolutional neural network") %>%
  bind_rows(results_summary) %>%
  write_tsv("All_Testing_Results.tsv")

###########################################################
# Summarize the misclassifications for CNN.
###########################################################

misclassification_summary1 = arrange(predictions, probability_unfriendly) %>%
  filter(label == "Definitely problematic") %>%
  filter(probability_unfriendly < 0.5) %>%
  mutate(predicted_label = "Definitely okay") %>%
  select(image_file_path, label, predicted_label, probability_unfriendly)

misclassification_summary2 = arrange(predictions, desc(probability_unfriendly)) %>%
  filter(label == "Definitely okay") %>%
  filter(probability_unfriendly > 0.5) %>%
  mutate(predicted_label = "Definitely problematic") %>%
  select(image_file_path, label, predicted_label, probability_unfriendly)

bind_rows(misclassification_summary1, misclassification_summary2) %>%
  dplyr::rename(probability_problematic = probability_unfriendly) %>%
  write_xlsx("CNN_Misclassifications_Testing.xlsx")

#######################################################

read_xlsx("CNN_Misclassifications_Testing_Annotated.xlsx") %>%
  pull(Conclusion) %>%
  table() %>%
  print()