library(tidyverse)

labeled_data = read_tsv("PMC_Selected_Articles_labeled.tsv") %>%
  mutate(image_file_path = str_c("PMC_Images/", Image_Number, "/original.jpg")) %>%
  dplyr::rename(Class = `Conclusion (5 types listed in drop down)`) %>%
  select(image_file_path, Class)

group_by(labeled_data, Class) %>%
  summarize(Count = n()) %>%
  print()

#  Class                  Count
#  <chr>                  <int>
#1 Definitely okay         1195
#2 Definitely problematic   104
#3 Gray-scale               662
#4 Probably okay             19
#5 Probably problematic      20

metrics_data = read_tsv("PMC_Metrics.tsv")

joined_data = inner_join(metrics_data, labeled_data) %>%
  filter(!is.na(euclidean_distance_metric)) %>%
  select(-article_id, -is_rgb)

# This results in 1285 images (non-grayscale according to automated inference).
group_by(joined_data, Class) %>%
  summarize(Count = n()) %>%
  print()

#. Class                  Count
#  <chr>                  <int>
#1 Definitely okay         1087
#2 Definitely problematic   104
#3 Gray-scale                55
#4 Probably okay             19
#5 Probably problematic      20

# This means there is a total of (2000-1285) + 55 = 770 grayscale images.
# That is 38.5%.

joined_data = filter(joined_data, Class %in% c("Definitely okay", "Definitely problematic")) %>%
  mutate(Class = factor(Class, levels = c("Definitely okay", "Definitely problematic"))) %>%
  mutate(Class = as.integer(Class) - 1)

select(joined_data, -image_file_path) %>%
  write_tsv("Image_Metrics_Classification_Data_PMC.tsv")

select(joined_data, image_file_path, Class) %>%
  write_tsv("PMC_Selected_Articles_for_testing.tsv")