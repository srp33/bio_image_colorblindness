library(tidyverse)
library(yardstick)

metrics_data = read_tsv("eLife_Metrics.tsv") %>%
  filter(!is_duplicate)

###############################################
# Compare the metrics against the curated
# labels.
###############################################

curated_data_training = read_tsv("Image_Curation_1-5000.tsv") %>%
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

curated_data_testing = read_tsv("Image_Curation_5001-6000.tsv") %>%
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

pull(curated_data_testing, visually_detect) %>%
  table() %>%
  print()

pull(curated_data_testing, contrasts_mitigate) %>%
  table() %>%
  print()

pull(curated_data_testing, labels_mitigate) %>%
  table() %>%
  print()

pull(curated_data_testing, distance_mitigates) %>%
  table() %>%
  print()

pull(curated_data_testing, conclusion) %>%
  table() %>%
  print()
# Definitely okay 
#   743 (74.3%)
# Probably okay 
#   41 (4.1%)
# Probably problematic 
#   23 (2.3%)
# Definitely problematic 
#   153 (15.3%)
# Gray-scale 
#   40 (4%)

metrics_data = mutate(metrics_data, image_file_name = basename(image_file_path)) %>%
  mutate(image_file_name = str_replace(image_file_name, "\\.jpg$", "")) %>%
  mutate(image_file_name = str_replace(image_file_name, "\\-v\\d$", ""))

###############################################
# Generate file that can be used for
# performing classification based on metrics.
###############################################

set.seed(33)

classification_data_training = inner_join(metrics_data, curated_data_training, by="image_file_name") %>%
  mutate(Class = as.character(conclusion)) %>%
  filter(Class %in% c("Definitely okay", "Definitely problematic")) %>%
  mutate(Class = factor(Class, levels = c("Definitely okay", "Definitely problematic"))) %>%
  filter(!is.na(euclidean_distance_metric)) %>%
  mutate(image_file_dir = basename(image_file_path)) %>%
  mutate(image_file_dir = str_replace(image_file_dir, "\\.jpg", "")) %>%
  mutate(image_file_path = str_c("ImageSample1to5000/", image_file_dir, "/original.jpg")) %>%
  mutate(deut_image_file_path = str_c("ImageSample1to5000/", image_file_dir, "/deut.jpg")) %>%
  dplyr::rename(image_id = image_file_dir) %>%
  mutate(image_id = str_replace(image_id, "-v\\d", "")) %>%
  select(image_id, image_file_path, deut_image_file_path, max_ratio, num_high_ratios, proportion_high_ratio_pixels, mean_delta, euclidean_distance_metric, Class)

classification_data_testing = inner_join(metrics_data, curated_data_testing, by="image_file_name") %>%
  mutate(Class = as.character(conclusion)) %>%
  filter(Class %in% c("Definitely okay", "Definitely problematic")) %>%
  mutate(Class = factor(Class, levels = c("Definitely okay", "Definitely problematic"))) %>%
  filter(!is.na(euclidean_distance_metric)) %>%
  mutate(image_file_dir = basename(image_file_path)) %>%
  mutate(image_file_dir = str_replace(image_file_dir, "\\.jpg", "")) %>%
  mutate(image_file_path = str_c("ImageSample5001to6000/", image_file_dir, "/original.jpg")) %>%
  mutate(deut_image_file_path = str_c("ImageSample5001to6000/", image_file_dir, "/deut.jpg")) %>%
  dplyr::rename(image_id = image_file_dir) %>%
  mutate(image_id = str_replace(image_id, "-v\\d", "")) %>%
  select(image_id, image_file_path, deut_image_file_path, max_ratio, num_high_ratios, proportion_high_ratio_pixels, mean_delta, euclidean_distance_metric, Class)

overlapping_image_ids = intersect(pull(classification_data_training, image_id), pull(classification_data_testing, image_id))

filter(classification_data_testing, !(image_id %in% overlapping_image_ids)) %>%
  select(-image_id) %>%
  mutate(Class = as.integer(Class) - 1) %>%
  write_tsv("Image_Metrics_Classification_Data_Testing.tsv")