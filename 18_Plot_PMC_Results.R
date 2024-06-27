library(pROC)
library(PRROC)
library(tidyverse)
library(writexl)

source("Functions.R")

###########################################################
# This is for the predictions based on metrics.
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