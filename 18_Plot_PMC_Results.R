library(pROC)
library(PRROC)
library(tidyverse)
library(writexl)

source("Functions.R")

###########################################################
# This is for the predictions based on image metrics.
###########################################################

predictions = read_tsv("PMC_Results_Predictions.tsv") %>%
  mutate(label = ifelse(label == 1, "Definitely problematic", "Definitely okay"))

plot_probabilities(predictions, "Metrics_PMC_Predictions")
plot_roc(predictions, "Metrics_PMC_ROC")
plot_prc(predictions, "Metrics_PMC_AUPRC")

###########################################################
# This is for the predictions based on CNN.
###########################################################

predictions = read_tsv("CNN_Metrics_PMC/predictions.tsv") %>%
  mutate(label = ifelse(label == "friendly", "Definitely okay", "Definitely problematic"))

plot_probabilities(predictions, "CNN_PMC_predictions")
plot_roc(predictions, "CNN_PMC_ROC")
plot_prc(predictions, "CNN_PMC_AUPRC")

###########################################################
# Parse and save the performance metrics.
###########################################################

results1 = read_tsv("PMC_Results_Metrics.tsv") %>%
  pivot_longer(everything()) %>%
  dplyr::rename(Metric = name, Value = value) %>%
  clean_performance_metrics("PubMed Central", "Logistic Regression")

results2 = read_tsv("CNN_Metrics_PMC/metrics.tsv") %>%
  dplyr::rename(Metric = metric, Value = value) %>%
  filter(Metric != "loss") %>%
  mutate(Metric = ifelse(Metric == "auc", "AUROC", Metric)) %>%
  mutate(Metric = ifelse(Metric == "prc", "AUPRC", Metric)) %>%
  clean_performance_metrics("PubMed Central", "Convolutional Neural Network")

read_tsv("All_Testing_Results.tsv", col_types = "cccc") %>%
  bind_rows(results1) %>%
  bind_rows(results2) %>%
  mutate(`Test set` = factor(`Test set`, levels = c("eLife", "PubMed Central"))) %>%
  mutate(`Model type` = factor(`Model type`, levels=c("Logistic Regression", "Convolutional Neural Network"))) %>%
  mutate(Metric = factor(Metric, levels = c("AUROC", "AUPRC", "Accuracy", "Precision", "Recall", "F1 score", "True positives", "True negatives", "False positives", "False negatives"))) %>%
  arrange(`Test set`, `Model type`, Metric) %>%
  write_xlsx("All_Testing_Results.xlsx")