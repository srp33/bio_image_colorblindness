library(tidyverse)

labeled_data = read_tsv("PMC_Selected_Articles_labeled.tsv") %>%
  mutate(image_file_path = str_c("PMC_Images/", Image_Number, "/original.jpg")) %>%
  dplyr::rename(Class = `Conclusion (5 types listed in drop down)`) %>%
  select(image_file_path, Class) %>%
  filter(Class %in% c("Definitely okay", "Definitely problematic")) %>%
  mutate(Class = factor(Class, levels = c("Definitely problematic", "Definitely okay")))

group_by(labeled_data, Class) %>%
  summarize(Count = n()) %>%
  print()

# Class                  Count
# <chr>                  <int>
# Definitely okay         1195
# Definitely problematic   104

mutate(labeled_data, Class = as.integer(Class) - 1) %>%
  write_tsv("PMC_Selected_Articles_for_testing.tsv")