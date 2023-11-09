library(colorspace)
library(dplyr)
library(grid)
library(httr)
library(magick)
library(spacesXYZ)
library(stringr)

# This is where the images downloaded from eLife are stored.
images_dirpath = "Images"

source("Functions.R")

create_simulated_image("/shared_dir/ImageSample1to5000/elife-00640-fig6-v1/original_downloaded.jpg", "/shared_dir/ImageSample1to5000/elife-00640-fig6-v1/deut.jpg")
create_simulated_image("/shared_dir/ImageSample1to5000/elife-12717-fig5-v2/original_downloaded.jpg", "/shared_dir/ImageSample1to5000/elife-12717-fig5-v2/deut.jpg")
create_simulated_image("/shared_dir/ImageSample1to5000/elife-14320-fig2-v1/original_downloaded.jpg", "/shared_dir/ImageSample1to5000/elife-14320-fig2-v1/deut.jpg")
create_simulated_image("/shared_dir/ImageSample1to5000/elife-26163-fig4-v2/original_downloaded.jpg", "/shared_dir/ImageSample1to5000/elife-26163-fig4-v2/deut.jpg")
create_simulated_image("/shared_dir/ImageSample1to5000/elife-26376-fig3-v2/original_downloaded.jpg", "/shared_dir/ImageSample1to5000/elife-26376-fig3-v2/deut.jpg")
create_simulated_image("/shared_dir/ImageSample1to5000/elife-64041-fig6-v2/original_downloaded.jpg", "/shared_dir/ImageSample1to5000/elife-64041-fig6-v2/deut.jpg")