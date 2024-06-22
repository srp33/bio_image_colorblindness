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

###########################################################
# This is for the predictions based on CNN.
###########################################################

predictions = read_tsv("CNN_Metrics_final/predictions.tsv") %>%
  mutate(label = ifelse(label == "friendly", "Definitely okay", "Definitely problematic"))

plot_probabilities(predictions, "CNN_Testing_predictions")
plot_roc(predictions, "CNN_Testing_ROC")
plot_prc(predictions, "CNN_Testing_AUPRC")

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