library(dplyr)
library(readr)

# This file is created by 1_Parse_Articles_from_XML.R.
articles_filepath = "all_eLife_articles.tsv"

# This is where the images downloaded from eLife are stored.
images_dirpath = "Images"

#######################################################################################

article_ids = read_tsv(articles_filepath) %>%
  filter(TYPE == "research article") %>%
  pull(`ARTICLE ID`)

all_image_file_paths = c()

for (article_id in article_ids) {
  article_dirpath = paste0(images_dirpath, "/", article_id)
  image_file_paths <- list.files(path = article_dirpath, pattern = "elife\\-\\d{5}\\-fig\\d+\\-v\\d+\\.jpg$", full.names = TRUE)
  all_image_file_paths <- c(all_image_file_paths, image_file_paths)
}

all_image_file_paths = unique(all_image_file_paths)

#print(length(article_ids))
#print(length(all_image_file_paths))

set.seed(0)
all_image_file_paths = sample(all_image_file_paths)[1:100]

sample_dirpath = "ImageSample100"

if (dir.exists(sample_dirpath))
  unlink(sample_dirpath, recursive=TRUE)

dir.create(sample_dirpath)

for (image_file_path in all_image_file_paths) {
  file.copy(image_file_path, paste0(sample_dirpath, "/", basename(image_file_path)), copy.date=TRUE)
}
