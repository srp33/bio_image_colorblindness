library(colorspace)
library(doParallel)
library(dplyr)
library(foreach)
library(grid)
library(httr)
library(magick)
library(readr)
library(spacesXYZ)
library(stringr)
library(tibble)


# This file is created by 1_Parse_Articles_from_XML.R.
articles_filepath = "all_eLife_articles.tsv"

# This is where the images downloaded from eLife are stored.
images_dirpath = "Images"

# This script will create this file.
metrics_filepath = "eLife_Metrics.tsv"

ratio_threshold = 5

#######################################################################################

source("Functions.R")

article_ids = read_tsv(articles_filepath) %>%
  filter(TYPE == "research article") %>%
  pull(`ARTICLE ID`)

my.cluster <- parallel::makeCluster(
  parallel::detectCores() / 2,
  type = "PSOCK"
)

doParallel::registerDoParallel(cl = my.cluster)

x = foreach(
    article_id = article_ids,
    .combine = "c",
    .packages = c("colorspace", "dplyr", "magick", "readr", "spacesXYZ", "stringr", "tibble")) %dopar% {
      process_article(article_id, paste0(images_dirpath, "/", article_id), paste0("TempResults/", article_id, ".tsv"), ratio_threshold)
}

write_tsv(tibble(x), "/shared_dir/status.tsv")
print("Saved to status.tsv")

tmp_file_paths = list.files(path="TempResults", pattern="*.tsv", full.names=TRUE)

scores_tbl = foreach(
    tmp_file_path = tmp_file_paths,
    .combine = 'bind_rows',
    .packages = c("readr")) %dopar% {
  read_tsv(tmp_file_path, col_types = c("c", "c", "d", "d", "d", "d", "d"))
}

parallel::stopCluster(cl = my.cluster)

write_tsv(scores_tbl, metrics_filepath)
print(paste0("Saved results to ", metrics_filepath))
