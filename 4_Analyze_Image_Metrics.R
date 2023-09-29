library(tidyverse)

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
  View()

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

#TODO:
# Use a classification algorithm to see how well we can predict "colorblind friendly status" based on the curated results.