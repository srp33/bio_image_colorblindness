library(colorspace)
library(doParallel)
library(dplyr)
library(foreach)
library(magick)
library(readr)
library(stringr)

num_to_sample = as.numeric(commandArgs(trailingOnly=TRUE)[1])
out_dirpath = commandArgs(trailingOnly=TRUE)[2]
out_filepath = commandArgs(trailingOnly=TRUE)[3]
alreadysampled_filepath = commandArgs(trailingOnly=TRUE)[4]
alreadysampled_filepath2 = commandArgs(trailingOnly=TRUE)[5]

#######################################################################################

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
  out_dir_path = paste0(out_dirpath, "/", basename(image_file_path))
  out_dir_path = sub(".jpg", "", out_dir_path)

  dir.create(out_dir_path, recursive=TRUE, showWarnings=FALSE)

  original_file_path = paste0(out_dir_path, "/original.jpg")
  deut_file_path = paste0(out_dir_path, "/deut.jpg")

  if (file.exists(deut_file_path))
      return(NULL)

  file.copy(image_file_path, original_file_path, copy.date=TRUE)
  create_simulated_image(image_file_path, deut_file_path)
}

alreadysampled_data = read_tsv(alreadysampled_filepath)

if (!is.na(alreadysampled_filepath2)) {
  alreadysampled_data2 = read_tsv(alreadysampled_filepath2)
  alreadysampled_data = bind_rows(alreadysampled_data, alreadysampled_data2)
}

alreadysampled_image_file_paths = pull(alreadysampled_data, image_file_path)

set.seed(33)

image_data = read_tsv(metrics_filepath) %>%
    filter(!(image_file_path %in% alreadysampled_image_file_paths)) %>%
    slice_sample(n = num_to_sample)

dir.create(out_dirpath, showWarnings=FALSE, recursive=TRUE)

image_file_paths = pull(image_data, image_file_path)

x = foreach(
    image_file_path = image_file_paths,
    .packages = c("colorspace", "dplyr", "magick", "stringr", "tibble")) %dopar% {
  process_image(image_file_path)
}

#for (image_file_path in image_file_paths) {
#  process_image(image_file_path)
#}

write_tsv(image_data, out_filepath)

parallel::stopCluster(cl = my.cluster)
