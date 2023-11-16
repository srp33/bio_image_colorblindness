library(pROC)
library(tidyverse)
library(writexl)

save_fig = function(file_name, width = 6.5, height=5) {
  ggsave(paste0("Figures/", file_name, ".png"), width=width, height=height)
  ggsave(paste0("Figures/", file_name, ".pdf"), width=width, height=height)
}

data = read_tsv("CNN_Metrics_final/predictions.tsv") %>%
  mutate(label = ifelse(label == "friendly", "Friendly", "Unfriendly"))

ggplot(data = data, aes(x = label, y = probability_unfriendly, col = label)) +
  geom_boxplot(outlier.shape = NA) +
  geom_jitter(height = 0, alpha = 0.3, size = 3) +
  theme_bw(base_size = 18) +
  guides(color = FALSE) +
  xlab("") +
  ylab("Confidence score (Unfriendly)") +
  scale_color_manual(values = c("#018571", "#a6611a"))

save_fig("CNN_Testing_predictions")

r = roc(label ~ probability_unfriendly, data = data)

ggroc(r, color = "darkred") +
  xlab("Specificity") +
  ylab("Sensitivity") +
  geom_segment(aes(x = 1, xend = 0, y = 0, yend = 1), color = "grey", linetype = "dashed") +
  scale_y_continuous(expand = c(0, 0)) +
  scale_x_reverse(expand = c(0, 0)) +
  theme_bw(base_size = 18) +
  annotate("text", x = 0.33, y = 0.05, label = legend_text)

save_fig("CNN_Testing_ROC")

misclassification_summary1 = arrange(data, probability_unfriendly) %>%
  filter(label == "Unfriendly") %>%
  filter(probability_unfriendly < 0.5) %>%
  mutate(predicted_label = "Friendly") %>%
  select(image_file_path, label, predicted_label, probability_unfriendly)

misclassification_summary2 = arrange(data, desc(probability_unfriendly)) %>%
  filter(label == "Friendly") %>%
  filter(probability_unfriendly > 0.5) %>%
  mutate(predicted_label = "Unfriendly") %>%
  select(image_file_path, label, predicted_label, probability_unfriendly)

bind_rows(misclassification_summary1, misclassification_summary2) %>%
  write_xlsx("CNN_Misclassifications_Testing.xlsx")

#data = read_tsv("CNN_Metrics_final/epoch_metrics.tsv")