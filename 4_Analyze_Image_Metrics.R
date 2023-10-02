library(tidyverse)

#img <- image_read("~/Downloads/elife-27134-fig7-v2.jpg")
img <- image_read("~/Downloads/original.jpg")
img <- image_convert(img, colorspace="srgb")
is_rgb <- image_info(img) %>%
  filter(colorspace == "sRGB") %>%
  nrow() > 0



metrics_data = read_tsv("eLife_Metrics.tsv")

###############################################
# Grayscale vs. RGB images
###############################################

x = group_by(metrics_data, is_rgb) %>%
  summarize(Count = n()) %>%
  arrange(is_rgb)

print("Num grayscale:")
print(x$Count[1]) #2940

print("Num RGB:")
print(x$Count[2]) #62986

print("Num both:")
print(sum(x$Count)) #65926

print("Percentage grayscale:")
print(100 * x$Count[1] / sum(x$Count)) #4.459%

print("Percentage RGB:")
print(100 * x$Count[2] / sum(x$Count)) #95.540%

###############################################
# Plot metrics for all images
###############################################

metrics_data = filter(metrics_data, is_rgb == 1)

# The mean, pixel-wise color distance between the original and simulated image
ggplot(metrics_data, aes(x = mean_delta)) +
  geom_histogram() +
  xlab("Mean, pixel-wise color distance\nbetween original and simulated images") +
  ylab("Count") +
  theme_bw()

# The color-distance ratio between the original and simulated images for the color pair with the largest distance in the original image
ggplot(metrics_data, aes(x = max_ratio)) +
  geom_histogram() +
  xlab("Maximum color-distance ratio\nbetween original and simulated images") +
  ylab("Count") +
  theme_bw()

# The number of color pairs that exhibited a high color-distance ratio between the original and simulated images
ggplot(metrics_data, aes(x = num_high_ratios)) +
  geom_histogram() +
  xlab("Number of high-ratio color pairs") +
  ylab("Count") +
  theme_bw()

# The proportion of pixels in the original image that used a color from one of the high-ratio color pairs
ggplot(metrics_data, aes(x = proportion_high_ratio_pixels)) +
  geom_histogram() +
  xlab("Proportion of pixels using high-ratio color pairs") +
  ylab("Count") +
  theme_bw()

# Mean Euclidean distance between pixels for high-ratio color pairs
ggplot(metrics_data, aes(x = euclidean_distance_metric)) +
  geom_histogram() +
  xlab("Mean distance between high-ratio color pairs") +
  ylab("Count") +
  theme_bw()

###############################################
# Correlation between metrics
###############################################

select(metrics_data, -article_id, -image_file_path, -is_rgb) %>%
  cor(method = "spearman") %>%
  print()

###############################################
# Use a ranking approach to combine metrics
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
# Compare these metrics against the curated
# labels.
###############################################

curated_data = read_tsv("Image_Curation_1-5000 - 1-5000.tsv") %>%
  dplyr::rename(image_file_name = `Image Names`) %>%
  dplyr::rename(visually_detect = `visually detect problem colors (Shades of red, green, and orange)`) %>%
  dplyr::rename(contrasts_mitigate = `Contrasts mitigate problem`) %>%
  dplyr::rename(labels_mitigate = `Labels mitigate problem`) %>%
  dplyr::rename(distance_mitigates = `Distance mitigates problem`) %>%
  dplyr::rename(conclusion = `Conclusion (5 types listed in drop down)`) %>%
  mutate(image_file_name = str_replace(image_file_name, "\\.jpg$", "")) %>%
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

metrics_data = mutate(metrics_data, image_file_name = basename(image_file_path)) %>%
  mutate(image_file_name = str_replace(image_file_name, "\\.jpg$", ""))

anti_join(curated_data, metrics_data, by="image_file_name") %>%
  View()

# curated_data = mutate(metrics_data, image_file_name = basename(image_file_path)) %>%
  # inner_join(curated_data, by="image_file_name")


# Plot the columns as bar plots (?).

# TODO:
# Use a classification algorithm (instead of ranking) to see how well we can predict "colorblind friendly status" based on the curated results?