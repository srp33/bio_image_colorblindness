library(colorspace)
library(doParallel)
library(dplyr)
library(foreach)
library(magick)
library(readr)
library(stringr)

# This file is created by 2_Process_Images.R
metrics_filepath = "eLife_Metrics.csv"

# This is where the images downloaded from eLife are stored.
images_dirpath = "Images"

#######################################################################################

my.cluster <- parallel::makeCluster(
  parallel::detectCores() / 2,
  type = "PSOCK"
)

doParallel::registerDoParallel(cl = my.cluster)

source("Functions.R")

process_image = function(image_file_path) {
  out_dir_path = paste0(sample_dirpath, "/", basename(image_file_path))
  out_dir_path = sub(".jpg", "", out_dir_path)

  dir.create(out_dir_path, recursive=TRUE, showWarnings=FALSE)

  original_file_path = paste0(out_dir_path, "/original.jpg")
  deut_file_path = paste0(out_dir_path, "/deut.jpg")

  if (file.exists(deut_file_path))
      return(NULL)

  file.copy(image_file_path, original_file_path, copy.date=TRUE)
  create_simulated_image(image_file_path, deut_file_path)
}

set.seed(33)

image_data = read_tsv(metrics_filepath) %>%
    slice_sample(n = 1000)

sample_dirpath = "ImageSample1000"

#if (dir.exists(sample_dirpath))
#  unlink(sample_dirpath, recursive=TRUE)

dir.create(sample_dirpath, showWarnings=FALSE, recursive=TRUE)

image_file_paths = pull(image_data, image_file_path)

#x = foreach(
#    image_file_path = image_file_paths,
#    .packages = c("colorspace", "dplyr", "magick", "stringr", "tibble")) %dopar% {
#  process_image(image_file_path)
#}

for (image_file_path in image_file_paths) {
  process_image(image_file_path)
}

write_tsv(image_data, "ImageSample1000_Metrics.tsv")

parallel::stopCluster(cl = my.cluster)
