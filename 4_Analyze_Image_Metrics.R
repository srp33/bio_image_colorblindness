library(tidyverse)
library(tidymodels)
library(randomForest)
library(yardstick)

metrics_data = read_tsv("eLife_Metrics.tsv") %>%
  filter(!is_duplicate)

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
  geom_histogram(binwidth = 0.005) +
  xlab("Mean, pixel-wise color distance\nbetween original and simulated images") +
  ylab("Count") +
  theme_bw()

# The color-distance ratio between the original and simulated images for the color pair with the largest distance in the original image
ggplot(plot_data, aes(x = max_ratio)) +
  geom_histogram(binwidth = 1) +
  xlab("Maximum color-distance ratio\nbetween original and simulated images") +
  ylab("Count") +
  theme_bw()

# The number of color pairs that exhibited a high color-distance ratio between the original and simulated images
ggplot(plot_data, aes(x = num_high_ratios)) +
  geom_histogram(binwidth=5) +
  xlab("Number of high-ratio color pairs") +
  ylab("Count") +
  theme_bw()

# The proportion of pixels in the original image that used a color from one of the high-ratio color pairs
ggplot(plot_data, aes(x = proportion_high_ratio_pixels)) +
  geom_histogram(binwidth=0.005) +
  xlab("Proportion of pixels using high-ratio color pairs") +
  ylab("Count") +
  theme_bw()

# Mean Euclidean distance between pixels for high-ratio color pairs
ggplot(plot_data, aes(x = euclidean_distance_metric)) +
  geom_histogram(binwidth=10) +
  xlab("Mean distance between high-ratio color pairs") +
  ylab("Count") +
  theme_bw()

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
#   3866
# Probably okay 
#   210
# Probably problematic 
#   74
# Definitely problematic 
#   636 
# Gray-scale 
#   179

metrics_data = mutate(metrics_data, image_file_name = basename(image_file_path)) %>%
  mutate(image_file_name = str_replace(image_file_name, "\\.jpg$", "")) %>%
  mutate(image_file_name = str_replace(image_file_name, "\\-v\\d$", ""))

###############################################
# Evaluate how well the metrics
# we can predict "colorblind friendly status"
# based on the curated results.
# Generate 
###############################################

set.seed(33)

classification_data = inner_join(metrics_data, curated_data, by="image_file_name") %>%
  mutate(Class = as.character(conclusion)) %>%
  filter(Class %in% c("Definitely okay", "Definitely problematic")) %>%
  mutate(Class = factor(Class, levels = c("Definitely problematic", "Definitely okay"))) %>%
  filter(!is.na(euclidean_distance_metric)) %>%
  select(image_file_path, max_ratio, num_high_ratios, proportion_high_ratio_pixels, mean_delta, euclidean_distance_metric, combined_score, Class)

alpha = 0.05
size = 0.7
color = "red"
base_size = 18

ggplot(classification_data, aes(x = Class, y = log2(max_ratio))) +
  geom_boxplot() +
  geom_jitter(alpha = alpha, size=size, color = color) +
  theme_bw(base_size = base_size) +
  xlab("") +
  ylab("Max color-distance ratio (log2 scale)")

ggplot(classification_data, aes(x = Class, y = log(num_high_ratios))) +
  geom_boxplot() +
  geom_jitter(alpha = alpha, size=size, color = color) +
  theme_bw() +
  xlab("") +
  ylab("Number of high-ratio color pairs (log2 scale)")

ggplot(classification_data, aes(x = Class, y = proportion_high_ratio_pixels)) +
  geom_boxplot() +
  geom_jitter(alpha = alpha, size=size, color = color) +
  theme_bw() +
  xlab("") +
  ylab("Proportion of high-ratio pixels")

ggplot(classification_data, aes(x = Class, y = mean_delta)) +
  geom_boxplot() +
  geom_jitter(alpha = alpha, size=size, color = color) +
  theme_bw() +
  xlab("") +
  ylab("Mean, pixel-wise color distance between original and simulated image")

ggplot(classification_data, aes(x = Class, y = euclidean_distance_metric)) +
  geom_boxplot() +
  geom_jitter(alpha = alpha, size=size, color = color) +
  theme_bw() +
  xlab("") +
  ylab("Mean Euclidean distance between pixels for high-ratio color pairs")

ggplot(classification_data, aes(x = Class, y = combined_score)) +
  geom_boxplot() +
  geom_jitter(alpha = alpha, size=size, color = color) +
  theme_bw() +
  xlab("") +
  ylab("Combined rank score")

# Calculate AUROC for each of these scores.

min_max_scale = function(x, inverse=FALSE) {
  y = (x - min(x, na.rm = TRUE)) / (max(x, na.rm = TRUE) - min(x, na.rm = TRUE))
  
  if (inverse)
    y = 1 - y
  
  y
}

auc_data = classification_data %>%
  mutate(max_ratio_scaled = min_max_scale(max_ratio)) %>%
  mutate(num_high_ratios_scaled = min_max_scale(num_high_ratios)) %>%
  mutate(proportion_high_ratio_pixels_scaled = min_max_scale(proportion_high_ratio_pixels)) %>%
  mutate(mean_delta_scaled = min_max_scale(mean_delta)) %>%
  mutate(euclidean_distance_metric_scaled = min_max_scale(euclidean_distance_metric, inverse=TRUE)) %>%
  mutate(combined_score_scaled = min_max_scale(combined_score, inverse=TRUE))

roc_auc(auc_data, Class, max_ratio_scaled) # 0.630
roc_auc(auc_data, Class, num_high_ratios_scaled) # 0.748
roc_auc(auc_data, Class, proportion_high_ratio_pixels_scaled) # 0.733
roc_auc(auc_data, Class, mean_delta_scaled) # 0.444
roc_auc(auc_data, Class, euclidean_distance_metric_scaled) # 0.673
roc_auc(auc_data, Class, combined_score_scaled) # 0.709

###############################################
# Generate file that can be used for
# performing classification.
###############################################

classification_data = select(classification_data, -combined_score) %>%
  mutate(Class = as.integer(Class) - 1)

write_tsv(classification_data, "Image_Metrics_Classification_Data.tsv")