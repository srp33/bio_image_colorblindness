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

# This file is created by 13_Select_PMC_Images.R.
articles_filepath = "PMC_Selected_Articles.tsv"

# This is where the images downloaded from eLife are stored.
images_dirpath = "PMC_Images"

# This script will create this file.
metrics_filepath = "PMC_Metrics.tsv"

ratio_threshold = 5

#######################################################################################

source("Functions.R")

if (!dir.exists("TempPMCResults")) {
  dir.create("TempPMCResults")
}

process_article = function(article_id, image_file_path, results_file_path, ratio_threshold) {
  if (file.exists(results_file_path)) {
      print(paste0("Already saved - ", results_file_path))
      return(NULL)
  }

#  tryCatch(
#      expr = { img_scores = calculate_image_metrics(article_id, image_file_path, ratio_threshold) },
#      error = function(e) { exc = e },
#      warning = function(w) { }
#  )

  img_scores = calculate_image_metrics(article_id, image_file_path, ratio_threshold)

#      if (is.null(img_scores)) {
#          next
#      }
#
#      if (is.null(scores_tbl)) {
#          scores_tbl <- img_scores
#      } else {
#          scores_tbl <- bind_rows(scores_tbl, img_scores)
#      }
#  }

#  if (is.null(scores_tbl)) {
#      return(paste0("Error occurred so that no valid images were found - ", results_file_path))
#  } else {
#      write_tsv(scores_tbl, results_file_path)
    write_tsv(img_scores, results_file_path)
    print(paste0("Saved - ", results_file_path))
#  }
}

image_numbers = read_tsv(articles_filepath) %>%
  pull(Image_Number)

my.cluster <- parallel::makeCluster(
  parallel::detectCores() / 2,
  type = "PSOCK"
)

doParallel::registerDoParallel(cl = my.cluster)

x = foreach(
    image_number = image_numbers,
    .combine = "c",
    .packages = c("colorspace", "dplyr", "magick", "readr", "spacesXYZ", "stringr", "tibble")) %dopar% {
      process_article(image_number, paste0(images_dirpath, "/", image_number, "/original.jpg"), paste0("TempPMCResults/", image_number, ".tsv"), ratio_threshold)
}

#for (image_number in image_numbers) {
#    print(image_number)
#    process_article(image_number, paste0(images_dirpath, "/", image_number, "/original.jpg"), paste0("TempPMCResults/", image_number, ".tsv"), ratio_threshold)
#}


tmp_file_paths = list.files(path="TempPMCResults", pattern="*.tsv", full.names=TRUE)

scores_tbl = foreach(
    tmp_file_path = tmp_file_paths,
    .combine = 'bind_rows',
    .packages = c("readr")) %dopar% {
  read_tsv(tmp_file_path, col_types = c("i", "c", "d", "d", "d", "d", "d"))
}

parallel::stopCluster(cl = my.cluster)

arrange(scores_tbl, article_id) %>%
  write_tsv(metrics_filepath)

print(paste0("Saved results to ", metrics_filepath))
