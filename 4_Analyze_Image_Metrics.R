library(broom)
library(diptest)
library(knitr)
library(PRROC)
library(randomForest)
library(tidyverse)
library(yardstick)

metrics_data = read_tsv("eLife_Metrics.tsv") %>%
  filter(!is_duplicate)

num_images = nrow(metrics_data) %>%
  print() # 66253

###############################################
# Identify images with at least one potentially
# problematic color pair.
###############################################

num_with_high_ratio = filter(metrics_data, is_rgb == 1) %>%
  filter(num_high_ratios > 0) %>%
  nrow() # 56816

print(num_with_high_ratio / num_images) # 0.8575612

###############################################
# Use a ranking approach to combine the metrics
# into a single score
###############################################

# A lower rank signals a greater possibility of being unfriendly.

metrics_data = mutate(metrics_data, combined_score =
                        (rank(-max_ratio) +
                         rank(-num_high_ratios) +
                         rank(-proportion_high_ratio_pixels) +
                         rank(-mean_delta) +
                         rank(euclidean_distance_metric)) / 5)

###############################################
# Grayscale vs. RGB images
###############################################

x = group_by(metrics_data, is_rgb) %>%
  summarize(Count = n()) %>%
  arrange(is_rgb)

print("Num grayscale:")
print(x$Count[1]) #1,744

print("Num RGB:")
print(x$Count[2]) #64,509

print("Num total:")
print(sum(x$Count)) #66,253

print("Percentage grayscale:")
print(100 * x$Count[1] / sum(x$Count)) #2.63%

print("Percentage RGB:")
print(100 * x$Count[2] / sum(x$Count)) #97.37%

###############################################
# Plot metrics for RGB images
###############################################

plot_data = filter(metrics_data, is_rgb == 1)

# The mean, pixel-wise color distance between the original and simulated image
ggplot(plot_data, aes(x = mean_delta)) +
  geom_histogram(binwidth = 0.003) +
  xlab("Mean, pixel-wise color distance between original and simulated images") +
  ylab("Count") +
  theme_bw()

if (!dir.exists("Figures"))
  dir.create("Figures")

ggsave("Figures/Mean_Pixelwise_Distance_histogram.pdf", width=6.5)

# Understand more about the bimodal distribution.
md = pull(plot_data, mean_delta)

print(dip.test(md))

print(sum(md < 0.01)) # 4708
print(sum(md < 0.01) / length(md)) # 0.07298206

md = pull(plot_data, mean_delta)
print(median(md[md >= 0.01])) # 0.04527808

# The color-distance ratio between the original and simulated images for the color pair with the largest distance in the original image
ggplot(plot_data, aes(x = max_ratio)) +
  geom_histogram(binwidth = 1) +
  xlab("Maximum color-distance ratio between original and simulated images") +
  ylab("Count") +
  theme_bw()

ggsave("Figures/Max_Color_Distance_Ratio_histogram.pdf", width=6.5)

mr = pull(plot_data, max_ratio)
print(dip.test(mr))

# The number of color pairs that exhibited a high color-distance ratio between the original and simulated images
ggplot(plot_data, aes(x = num_high_ratios)) +
  geom_histogram(binwidth=5) +
  xlab("Number of high-ratio color pairs") +
  ylab("Count") +
  theme_bw()

ggsave("Figures/Num_High_Ratio_Pairs_histogram.pdf", width=6.5)

nhr = pull(plot_data, num_high_ratios)
print(dip.test(nhr))

# The proportion of pixels in the original image that used a color from one of the high-ratio color pairs
ggplot(plot_data, aes(x = proportion_high_ratio_pixels)) +
  geom_histogram(binwidth=0.01) +
  xlab("Proportion of pixels using high-ratio color pairs") +
  ylab("Count") +
  theme_bw()

ggsave("Figures/Proportion_Pixels_High_Ratio_Color_Pairs_histogram.pdf", width=6.5)

phrp = pull(plot_data, proportion_high_ratio_pixels)
print(dip.test(phrp))

# Mean Euclidean distance between pixels for high-ratio color pairs
ggplot(plot_data, aes(x = euclidean_distance_metric)) +
  geom_histogram(binwidth=5) +
  xlab("Mean distance between high-ratio color pairs") +
  ylab("Count") +
  theme_bw()

ggsave("Figures/Mean_Euclidean_Distance_Color_Pairs_histogram.pdf", width=6.5)

edm = pull(plot_data, euclidean_distance_metric)
print(dip.test(edm))

###############################################
# Correlation between metrics
###############################################

select(plot_data, -article_id, -image_file_path, -is_rgb, -is_duplicate, -combined_score) %>%
  cor(method = "spearman", use="pairwise.complete.obs") %>%
  print()

###############################################
# Compare the metrics against the curated
# labels.
###############################################

curated_data = read_tsv("Image_Curation_1-5000.tsv") %>%
  dplyr::rename(image_file_name = `Image Names`) %>%
  dplyr::rename(visually_detect = `visually detect problem colors (Shades of red, green, and orange)`) %>%
  dplyr::rename(contrasts_mitigate = `Contrasts mitigate problem`) %>%
  dplyr::rename(labels_mitigate = `Labels mitigate problem`) %>%
  dplyr::rename(distance_mitigates = `Distance mitigates problem`) %>%
  dplyr::rename(conclusion = `Conclusion (5 types listed in drop down)`) %>%
  mutate(image_file_name = str_replace(image_file_name, "\\.jpg$", "")) %>%
  mutate(image_file_name = str_replace(image_file_name, "\\-v\\d$", "")) %>%
  mutate(contrasts_mitigate = contrasts_mitigate == "Y") %>%
  mutate(labels_mitigate = labels_mitigate == "Y") %>%
  mutate(distance_mitigates = distance_mitigates == "Y") %>%
  mutate(conclusion = factor(conclusion, levels = c("Definitely okay", "Probably okay", "Probably problematic", "Definitely problematic", "Gray-scale")))

# Look at the unique values for these and make sure there are no type-os.

pull(curated_data, visually_detect) %>%
  table() %>%
  print()

pull(curated_data, contrasts_mitigate) %>%
  table() %>%
  print()

pull(curated_data, labels_mitigate) %>%
  table() %>%
  print()

pull(curated_data, distance_mitigates) %>%
  table() %>%
  print()

pull(curated_data, conclusion) %>%
  table() %>%
  print()
# Definitely okay 
#   3865 (77.9%)
# Probably okay 
#   210
# Probably problematic 
#   74
# Definitely problematic 
#   636 (12.8%)
# Gray-scale 
#   179

# How often could we visually detect potentially problematic colors?
filter(curated_data, conclusion == "Definitely okay") %>%
  group_by(visually_detect) %>%
  summarize(count = n()) %>%
  print()

# How often did color contrasts, distances, or labels mitigate potentially problematic colors?
filter(curated_data, conclusion == "Definitely okay") %>%
  filter(visually_detect) %>%
  select(-visually_detect, -conclusion, -Notes) %>%
  pivot_longer(-image_file_name, names_to = "criteria", values_to = "value") %>%
  group_by(criteria) %>%
  filter(!is.na(value)) %>%
  summarize(total = n(), mitigates_count = sum(value)) %>%
  ungroup() %>%
  mutate(mitigates_percent = mitigates_count / total) %>%
  print()

metrics_data = mutate(metrics_data, image_file_name = basename(image_file_path)) %>%
  mutate(image_file_name = str_replace(image_file_name, "\\.jpg$", "")) %>%
  mutate(image_file_name = str_replace(image_file_name, "\\-v\\d$", ""))

###############################################
# Evaluate how well the metrics
# can predict "colorblind friendly status"
# based on the curated results.
###############################################

set.seed(33)

classification_data = inner_join(metrics_data, curated_data, by="image_file_name") %>%
  mutate(Class = as.character(conclusion)) %>%
  filter(Class %in% c("Definitely okay", "Definitely problematic")) %>%
  mutate(Class = factor(Class, levels = c("Definitely okay", "Definitely problematic"))) %>%
  filter(!is.na(euclidean_distance_metric)) %>%
  mutate(image_file_dir = basename(image_file_path)) %>%
  mutate(image_file_dir = str_replace(image_file_dir, "\\.jpg", "")) %>%
  mutate(image_file_path = str_c("ImageSample1to5000/", image_file_dir, "/original.jpg")) %>%
  mutate(deut_image_file_path = str_c("ImageSample1to5000/", image_file_dir, "/deut.jpg")) %>%
  select(image_file_path, deut_image_file_path, max_ratio, num_high_ratios, proportion_high_ratio_pixels, mean_delta, euclidean_distance_metric, combined_score, Class)

alpha = 0.08
size = 0.8
color = "red"
base_size = 14

ggplot(classification_data, aes(x = Class, y = mean_delta)) +
  geom_boxplot() +
  geom_jitter(alpha = alpha, size=size, color = color) +
  theme_bw() +
  xlab("") +
  ylab("Mean, pixel-wise color distance\nbetween original and simulated image")

ggsave("Figures/Mean_Pixelwise_Distance_boxplot.pdf", width=6.5)

ggplot(classification_data, aes(x = Class, y = log2(max_ratio))) +
  geom_boxplot() +
  geom_jitter(alpha = alpha, size=size, color = color) +
  theme_bw(base_size = base_size) +
  xlab("") +
  ylab("Max color-distance ratio (log2 scale)")

ggsave("Figures/Max_Color_Distance_Ratio_boxplot.pdf", width=6.5)

ggplot(classification_data, aes(x = Class, y = log(num_high_ratios))) +
  geom_boxplot() +
  geom_jitter(alpha = alpha, size=size, color = color) +
  theme_bw() +
  xlab("") +
  ylab("Number of high-ratio color pairs (log2 scale)")

ggsave("Figures/Num_High_Ratio_Pairs_boxplot.pdf", width=6.5)

ggplot(classification_data, aes(x = Class, y = proportion_high_ratio_pixels)) +
  geom_boxplot() +
  geom_jitter(alpha = alpha, size=size, color = color) +
  theme_bw() +
  xlab("") +
  ylab("Proportion of high-ratio pixels")

ggsave("Figures/Proportion_Pixels_High_Ratio_Color_Pairs_boxplot.pdf", width=6.5)

ggplot(classification_data, aes(x = Class, y = euclidean_distance_metric)) +
  geom_boxplot() +
  geom_jitter(alpha = alpha, size=size, color = color) +
  theme_bw() +
  xlab("") +
  ylab("Mean Euclidean distance between\npixels for high-ratio color pairs")

ggsave("Figures/Mean_Euclidean_Distance_Color_Pairs_boxplot.pdf", width=6.5)

ggplot(classification_data, aes(x = Class, y = combined_score)) +
  geom_boxplot() +
  geom_jitter(alpha = alpha, size=size, color = color) +
  theme_bw() +
  xlab("") +
  ylab("Combined rank score")

ggsave("Figures/Combined_Rank_Score_boxplot.pdf", width=6.5)

# Calculate AUROC and AUPRC for each of these scores.

min_max_scale = function(x, inverse=FALSE) {
  y = (x - min(x, na.rm = TRUE)) / (max(x, na.rm = TRUE) - min(x, na.rm = TRUE))
  
  if (inverse)
    y = 1 - y
  
  y
}

calc_auprc = function(scores, labels) {
  pr_curve <- pr.curve(scores.class0 = scores, weights.class0 = labels, curve = TRUE)
  return(pr_curve$auc.integral)
}

auc_data = classification_data %>%
  mutate(max_ratio_scaled = min_max_scale(max_ratio)) %>%
  mutate(num_high_ratios_scaled = min_max_scale(num_high_ratios)) %>%
  mutate(proportion_high_ratio_pixels_scaled = min_max_scale(proportion_high_ratio_pixels)) %>%
  mutate(mean_delta_scaled = min_max_scale(mean_delta)) %>%
  mutate(euclidean_distance_metric_scaled = min_max_scale(euclidean_distance_metric, inverse=TRUE)) %>%
  mutate(combined_score_scaled = min_max_scale(combined_score, inverse=TRUE))

max_ratio_scaled_auroc = pull(roc_auc(auc_data, Class, max_ratio_scaled), .estimate) # 0.630
num_high_ratios_scaled_auroc = pull(roc_auc(auc_data, Class, num_high_ratios_scaled), .estimate) # 0.748
proportion_high_ratio_pixels_scaled_auroc = pull(roc_auc(auc_data, Class, proportion_high_ratio_pixels_scaled), .estimate) # 0.733
mean_delta_scaled_auroc = pull(roc_auc(auc_data, Class, mean_delta_scaled), .estimate) # 0.444
euclidean_distance_metric_scaled_auroc = pull(roc_auc(auc_data, Class, euclidean_distance_metric_scaled), .estimate) # 0.673
combined_score_scaled_auroc = pull(roc_auc(auc_data, Class, combined_score_scaled), .estimate) # 0.709

max_ratio_scaled_auprc = calc_auprc(pull(auc_data, max_ratio_scaled), pull(auc_data, Class) == "Definitely problematic")
num_high_ratios_scaled_auprc = calc_auprc(pull(auc_data, num_high_ratios_scaled), pull(auc_data, Class) == "Definitely problematic")
proportion_high_ratio_pixels_scaled_auprc = calc_auprc(pull(auc_data, proportion_high_ratio_pixels_scaled), pull(auc_data, Class) == "Definitely problematic")
mean_delta_scaled_auprc = calc_auprc(pull(auc_data, mean_delta_scaled), pull(auc_data, Class) == "Definitely problematic")
euclidean_distance_metric_scaled_auprc = calc_auprc(pull(auc_data, euclidean_distance_metric_scaled), pull(auc_data, Class) == "Definitely problematic")
combined_score_scaled_auprc = calc_auprc(pull(auc_data, combined_score_scaled), pull(auc_data, Class) == "Definitely problematic")

tribble(~"Metric", ~"AUROC", ~"AUPRC",
        "Mean, pixel-wise color distance between the original and simulated image", round(mean_delta_scaled_auroc, 2), round(mean_delta_scaled_auprc, 2),
        "Color-distance ratio between the original and simulated images for the color pair with the largest distance in the original image", round(max_ratio_scaled_auroc, 2), round(max_ratio_scaled_auprc, 2),
        "Number of color pairs that exhibited a high color-distance ratio between the original and simulated images", round(num_high_ratios_scaled_auroc, 2), round(num_high_ratios_scaled_auprc, 2),
        "Proportion of pixels in the original image that used a color from one of the high-ratio color pairs", round(proportion_high_ratio_pixels_scaled_auroc, 2), round(proportion_high_ratio_pixels_scaled_auprc, 2),
        "Mean Euclidean distance between pixels for high-ratio color pairs", round(euclidean_distance_metric_scaled_auroc, 2), round(euclidean_distance_metric_scaled_auprc, 2),
        "Rank-based score that combines the metrics", round(combined_score_scaled_auroc, 2), round(combined_score_scaled_auprc, 2)) %>%
  kable(format="simple") %>%
  write("Tables/Metrics_AUROC_AUPRC.md")

###############################################
# Generate file that can be used for
# performing classification.
###############################################

classification_data = select(classification_data, -combined_score) %>%
  mutate(Class = as.integer(Class) - 1)

write_tsv(classification_data, "Image_Metrics_Classification_Data.tsv")

###############################################
# Evaluate trends over time.
###############################################

article_data = read_tsv("all_eLife_articles.tsv") %>%
  dplyr::rename(article_id = `ARTICLE ID`) %>%
  dplyr::rename(subjects = `SUBJECT(S)`) %>%
  separate(DATE, sep="-", into=c("year", "month", "day"))

article_data_year = select(article_data, article_id, year)

collapse_conclusions = function(conclusions) {
  if ("Definitely problematic" %in% conclusions) {
    return("Definitely problematic")
  }
  
  return("Definitely okay")
}

# Summarize to article level
curated_article_data = separate(curated_data, image_file_name, sep="-", into=c("x", "article_id", "y")) %>%
  select(article_id, conclusion) %>%
  filter(conclusion %in% c("Definitely okay", "Definitely problematic")) %>%
  group_by(article_id) %>%
  summarize(conclusion = collapse_conclusions(conclusion)) %>%
  ungroup()

plot_data_year = inner_join(curated_article_data, article_data_year) %>%
  arrange(year, conclusion) %>%
  group_by(year, conclusion) %>%
  summarize(count = n()) %>%
  ungroup() %>%
  mutate(year = as.integer(year))

logistic_data = pivot_wider(plot_data_year, names_from = conclusion, values_from = count) %>%
  dplyr::rename(okay = `Definitely okay`, problematic = `Definitely problematic`)

logistic_model = glm(cbind(okay, problematic) ~ year, family = binomial, data = logistic_data)
logistic_results = tidy(logistic_model)
slope = pull(logistic_results, estimate)[2] # 0.103
p_value = pull(logistic_results, p.value)[2] # 6.76e-8

ggplot(plot_data_year, aes(x = factor(year), y = count, fill = conclusion)) +
  geom_col(position = "dodge") +
  xlab("Year") +
  ylab("Count") +
  labs(fill = "") +
  theme_bw(base_size = 14) +
  scale_fill_manual(values = c(`Definitely okay` = "#5aae61", `Definitely problematic` = "#9970ab"))
#  geom_text(aes(x = 12, y = 450, label = p_value), hjust = 1, vjust = 1)

ggsave("Figures/Proportion_Problematic_Over_Time_barplot.pdf", width=8.5)

###############################################
# Evaluate trends by subdiscipline.
###############################################

collapse_subjects = function(subjects) {
  if (length(subjects) == 1) {
    return(subjects)
  } else {
    return("Multidisciplinary")
  }
}

article_data_subjects = select(article_data, article_id, subjects) %>%
  separate(subjects, sep=", ", into=paste0("X", 1:50)) %>%
  pivot_longer(paste0("X", 1:50), names_to = "ignore", values_to = "subject") %>%
  filter(!is.na(subject)) %>%
  select(-ignore) %>%
  group_by(article_id) %>%
  summarize(subject = collapse_subjects(subject))

plot_data_subjects = inner_join(curated_article_data, article_data_subjects, relationship = "many-to-many") %>%
  arrange(subject, conclusion) %>%
  group_by(subject, conclusion) %>%
  summarize(count = n()) %>%
  ungroup() %>%
  pivot_wider(names_from = conclusion, values_from = count) %>%
  mutate(n = `Definitely problematic` + `Definitely okay`) %>%
  mutate(proportion_problematic = 100 * `Definitely problematic` / n) %>%
  mutate(label = str_c(subject, " (n = ", n, ")")) %>%
  mutate(label = factor(label, levels=rev(label))) %>%
  mutate(severity = ifelse(proportion_problematic > 20, "high", ifelse(proportion_problematic > 10, "medium", "low"))) %>%
  mutate(severity = factor(severity, levels = c("low", "medium", "high")))

actual = pull(plot_data_subjects, `Definitely problematic`)
expected_proportions = pull(plot_data_subjects, n) / sum(pull(plot_data_subjects, n))
p_value = chisq.test(actual, p = expected_proportions, correct = FALSE)$p.value
p_text = paste0("p = ", sprintf("%.1e", p_value))
print(p_text)

ggplot(plot_data_subjects, aes(x = label, y = proportion_problematic)) +
  geom_col(aes(fill = severity)) +
  scale_fill_manual(values = c("#74add1", "#fdae61", "#d73027")) +
  xlab("") +
  ylab("% Definitely problematic") +
  theme_bw(base_size=12) +
  coord_flip() +
  guides(fill = FALSE) +
  geom_text(aes(x = 18.5, y = 38.5, label = p_text), size = 3)

ggsave("Figures/Proportion_Problematic_Subjects_barplot.pdf", width=6.5)