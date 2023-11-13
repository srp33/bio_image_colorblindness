library(tidyverse)
library(writexl)

data = read_tsv("CNN_Metrics_final/predictions.tsv")

ggplot(data = data, aes(x = label, y = probability_unfriendly, col = label)) +
  geom_boxplot(outlier.shape = NA) +
  geom_jitter(height = 0) +
  theme_bw() +
  guides(color = FALSE)


misclassification_summary1 = arrange(data, probability_unfriendly) %>%
  filter(label == "unfriendly") %>%
  head(n = 10)

misclassification_summary2 = arrange(data, desc(probability_unfriendly)) %>%
  filter(label == "friendly") %>%
  head(n = 10)

bind_rows(misclassification_summary1, misclassification_summary2) %>%
  write_xlsx("CNN_Top_Misclassifications.xlsx")