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

modimages_dirpath = "ModImages"

# This script will create this file.
metrics_filepath = "eLife_Metrics.csv"

ratio_threshold = 5

#######################################################################################

#dir.create(modimages_dirpath, recursive = TRUE, showWarnings = FALSE)

source("Functions.R")

article_ids = read_tsv(articles_filepath) %>%
  filter(TYPE == "research article") %>%
  pull(`ARTICLE ID`)

#scores_tbl = NULL

#for (article_id in article_ids) {
#  article_dirpath = paste0(images_dirpath, "/", article_id)
#  article_scores_tbl = process_article(article_dirpath)
#  
#  if (is.null(article_scores_tbl)) {
#    scores_tbl <- article_scores_tbl
#  } else {
#    scores_tbl <- bind_rows(scores_tbl, article_scores_tbl)
#  }
#break
#}

my.cluster <- parallel::makeCluster(
  parallel::detectCores() - 1,
  type = "PSOCK"
)

doParallel::registerDoParallel(cl = my.cluster)

foreach(
    article_id = article_ids[1:5],
    .packages = c("colorspace", "dplyr", "magick", "readr", "spacesXYZ", "stringr", "tibble")) %dopar% {
  process_article(paste0(images_dirpath, "/", article_id, paste0("TempResults/", article_id, ".tsv"))
)}

scores_tbl = foreach(
    article_id = article_ids[1:5],
    .combine = 'bind_rows',
    .packages = c("readr")) %dopar% {
  read_tsv(paste0("TempResults/", article_id, ".tsv"))
}

parallel::stopCluster(cl = my.cluster)

print(scores_tbl)

#write_tsv(scores_tbl, metrics_filepath)
