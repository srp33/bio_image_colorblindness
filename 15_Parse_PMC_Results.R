library(tidyverse)

labeled_data = read_tsv("PMC_Selected_Articles_labeled.tsv") %>%
  mutate(image_file_path = str_c("PMC_Images/", Image_Number, "/original.jpg")) %>%
  dplyr::rename(Class = `Conclusion (5 types listed in drop down)`) %>%
  select(image_file_path, Class) %>%
  filter(Class %in% c("Definitely okay", "Definitely problematic")) %>%
  mutate(Class = factor(Class, levels = c("Definitely okay", "Definitely problematic")))

group_by(labeled_data, Class) %>%
  summarize(Count = n()) %>%
  print()

# Class                  Count
# <chr>                  <int>
# Definitely okay         1195
# Definitely problematic   104

labeled_data = mutate(labeled_data, Class = as.integer(Class) - 1)

metrics_data = read_tsv("PMC_Metrics.tsv")

joined_data = inner_join(metrics_data, labeled_data) %>%
  filter(!is.na(euclidean_distance_metric)) %>%
  select(-article_id, -is_rgb)

select(joined_data, -image_file_path) %>%
  write_tsv("Image_Metrics_Classification_Data_PMC.tsv")

select(joined_data, image_file_path, Class) %>%
  write_tsv("PMC_Selected_Articles_for_testing.tsv")