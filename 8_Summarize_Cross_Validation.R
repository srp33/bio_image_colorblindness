library(knitr)
library(tidyverse)

metrics_data = read_tsv("Cross_Validation_Results_Metrics.tsv") %>%
  group_by(algorithm, iteration) %>%
  summarise(auroc = median(auroc)) %>%
  group_by(algorithm) %>%
  summarize(auroc = mean(auroc))

cnn_data = read_tsv("Cross_Validation_Results_CNN.tsv") %>%
  group_by(algorithm, iteration) %>%
  summarise(auroc = median(auroc)) %>%
  summarize(auroc = mean(auroc))

#Use kable() to create the tables in Markdown.