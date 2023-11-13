library(knitr)
library(tidyverse)

save_fig = function(file_name, width=6.5) {
  ggsave(paste0("Figures/", file_name, ".png"), width=width)
  ggsave(paste0("Figures/", file_name, ".pdf"), width=width)
}

dir.create("Figures", showWarnings = FALSE, recursive = TRUE)
dir.create("Tables", showWarnings = FALSE, recursive = TRUE)

read_tsv("Cross_Validation_Results_Metrics.tsv") %>%
  group_by(algorithm, iteration) %>%
  summarise(auroc = median(auroc)) %>%
  group_by(algorithm) %>%
  summarize(auroc = mean(auroc)) %>%
  mutate(auroc = round(auroc, 2)) %>%
  dplyr::rename(Algorithm = algorithm) %>%
  dplyr::rename(AUROC = auroc) %>%
  kable(format="simple") %>%
  write("Tables/Cross_Validation_Results_Metrics.md")

cnn_data = read_tsv("Cross_Validation_Results_CNN.tsv") %>%
  group_by(algorithm, image_type, iteration) %>%
  summarise(auroc = median(auroc)) %>%
  group_by(algorithm, image_type) %>%
  summarize(auroc = mean(auroc)) %>%
  mutate(image_type = ifelse(image_type == "deut", "Deuteranopia simulated", "Original colors")) %>%
  mutate(image_type = factor(image_type, levels = c("Original colors", "Deuteranopia simulated"))) %>%
  mutate(algorithm = factor(algorithm, levels = as.character(0:22)))

baseline = filter(cnn_data, algorithm == 0 & image_type == "Original colors")$auroc

ggplot(cnn_data, aes(x = algorithm, y = auroc, fill = image_type)) +
  geom_col(position = "dodge", width=0.6) +
  geom_hline(yintercept = baseline, linetype = "dashed", linewidth = 0.5) +
  xlab("Hyperparameter combination") +
  ylab("Summarized AUROC") +
  theme_bw() +
  labs(fill = "") +
  scale_fill_manual(values = c("#5aae61", "#9970ab"))

save_fig("Hyperparameter_Configurations")

######################################################

hyperparameters = tribble(~`Hyperparameter combination`, ~`Class weighting`, ~`Early stopping`, ~`Random rotation`, ~`Dropout`, ~`Transfer learning`, ~`Fine tuning`,
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
  mutate(`Hyperparameter combination` = factor(`Hyperparameter combination`, levels = as.character(0:22)))

filter(cnn_data, image_type == "Original colors") %>%
  dplyr::rename(`Hyperparameter combination` = algorithm) %>%
  inner_join(hyperparameters, by = "Hyperparameter combination") %>%
  select(-image_type) %>%
  select(-auroc, everything()) %>%
  dplyr::rename(AUROC = auroc) %>%
  mutate(AUROC = round(AUROC, 2)) %>%
  kable(format="simple") %>%
  write("Tables/Hyperparameter_Combination_Results.md")