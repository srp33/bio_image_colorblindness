library(knitr)
library(tidyverse)

save_fig = function(file_name, width=6.5) {
  ggsave(paste0("Figures/", file_name, ".png"), width=width)
  ggsave(paste0("Figures/", file_name, ".pdf"), width=width)
}

dir.create("Figures", showWarnings = FALSE, recursive = TRUE)
dir.create("Tables", showWarnings = FALSE, recursive = TRUE)

read_tsv("Cross_Validation_Results_Metrics.tsv") %>%
  pivot_wider(names_from = metric, values_from = value) %>%
  group_by(algorithm, iteration) %>%
  summarise(AUROC = median(AUROC), AUPRC = median(AUPRC)) %>%
  group_by(algorithm) %>%
  summarize(AUROC = mean(AUROC), AUPRC = mean(AUPRC)) %>%
  mutate(AUROC = round(AUROC, 2), AUPRC = round(AUPRC, 2)) %>%
  dplyr::rename(Algorithm = algorithm) %>%
  kable(format="simple") %>%
  write("Tables/Cross_Validation_Results_Metrics.md")

cnn_data = read_tsv("Cross_Validation_Results_CNN.tsv") %>%
  group_by(algorithm, image_type, iteration) %>%
  summarise(auroc = median(auroc), auprc = median(auprc)) %>%
  group_by(algorithm, image_type) %>%
  summarize(auroc = mean(auroc), auprc = mean(auprc)) %>%
  ungroup() %>%
  mutate(image_type = ifelse(image_type == "deut", "Deuteranopia simulated", "Original colors")) %>%
  mutate(image_type = factor(image_type, levels = c("Original colors", "Deuteranopia simulated"))) %>%
  mutate(Combination = factor(algorithm, levels = as.character(0:22))) %>%
  select(-algorithm)

baseline = filter(cnn_data, Combination == 0 & image_type == "Original colors")$auprc

ggplot(cnn_data, aes(x = Combination, y = auprc, fill = image_type)) +
  geom_col(position = "dodge", width=0.6) +
  geom_hline(yintercept = baseline, linetype = "dashed", linewidth = 0.5) +
  xlab("Combination") +
  ylab("Summarized AUPRC") +
  theme_bw() +
  labs(fill = "") +
  scale_fill_manual(values = c("#5aae61", "#9970ab"))

save_fig("Hyperparameter_Configurations")

######################################################

hyperparameters = tribble(~`Combination`, ~`Class weighting`, ~`Early stopping`, ~`Random rotation`, ~`Dropout`, ~`Transfer learning`, ~`Fine tuning`,
                          0, "No", "No", 0.0, 0.0, "None", "No",
                          1, "Yes", "No", 0.0, 0.0, "None", "No",
                          2, "No", "Yes", 0.0, 0.0, "None", "No",
                          3, "No", "No", 0.2, 0.0, "None", "No",
                          4, "No", "No", 0.3, 0.0, "None", "No",
                          5, "No", "No", 0.0, 0.2, "None", "No",
                          6, "No", "No", 0.0, 0.5, "None", "No",
                          7, "No", "No", 0.0, 0.0, "MobileNetV2", "No",
                          8, "No", "No", 0.0, 0.0, "ResNet50", "No",
                          9, "No", "No", 0.0, 0.0, "MobileNetV2", "Yes",
                          10, "No", "No", 0.0, 0.0, "ResNet50", "Yes",
                          11, "Yes", "Yes", 0.2, 0.0, "ResNet50", "No",
                          12, "Yes", "Yes", 0.2, 0.2, "ResNet50", "No",
                          13, "Yes", "Yes", 0.2, 0.5, "ResNet50", "No",
                          14, "Yes", "Yes", 0.2, 0.0, "ResNet50", "Yes",
                          15, "Yes", "Yes", 0.2, 0.2, "ResNet50", "Yes",
                          16, "Yes", "Yes", 0.2, 0.5, "ResNet50", "Yes",
                          17, "Yes", "Yes", 0.2, 0.0, "MobileNetV2", "No",
                          18, "Yes", "Yes", 0.2, 0.2, "MobileNetV2", "No",
                          19, "Yes", "Yes", 0.2, 0.5, "MobileNetV2", "No",
                          20, "Yes", "Yes", 0.2, 0.0, "MobileNetV2", "Yes",
                          21, "Yes", "Yes", 0.2, 0.2, "MobileNetV2", "Yes",
                          22, "Yes", "Yes", 0.2, 0.5, "MobileNetV2", "Yes") %>%
  mutate(`Combination` = factor(`Combination`, levels = as.character(0:22)))

cnn_data2 = filter(cnn_data, image_type == "Original colors") %>%
  select(-image_type)

inner_join(hyperparameters, cnn_data2) %>%
  dplyr::rename(AUROC = auroc) %>%
  mutate(AUROC = round(AUROC, 2)) %>%
  dplyr::rename(AUPRC = auprc) %>%
  mutate(AUPRC = round(AUPRC, 2)) %>%
  kable(format="simple") %>%
  write("Tables/Hyperparameter_Combination_Results.md")