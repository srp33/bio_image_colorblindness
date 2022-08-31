#install.packages(c("colorblindcheck", "colorBlindness", "tibble", "png", "jpeg", "dplyr", "httr", "stringr"))

#install.packages("magick")
#install.packages("colorspace")

library(colorblindcheck) #for palette_dist() function
library(colorBlindness) #for cvdPlot() function
library(tibble)
library(grid)
library(jpeg)
library(dplyr)
library(httr)
library(stringr)
library(readr)

library(magick)
library(colorspace)
library(spacesXYZ)

# NOTE: User must set the working directory to the location where this script is stored.
# NOTE: User can modify the paths below to indicate where the input and output files are / will be stored.

# This file is created by 1_Parse_Articles_from_XML.R.
articles_filepath = "all_eLife_articles.tsv"

# This is where the images downloaded from eLife are stored.
images_dirpath = "Images"

modimages_dirpath = "ModImages"

# This script will create this file.
metrics_filepath = "Metrics.csv"

ratio_threshold = 5

#######################################################################################

dir.create(modimages_dirpath, recursive = TRUE, showWarnings = FALSE)

source("Functions.R")

article_ids = read_tsv(articles_filepath) %>%
  filter(TYPE == "research article") %>%
  pull(`ARTICLE ID`)

scores_tbl = NULL

for (article_id in article_ids) {
  article_dirpath = paste0(images_dirpath, "/", article_id)
  
  # Gets path to images inside an article's directory
  image_file_paths <- list.files(path = article_dirpath, pattern = "elife\\-\\d{5}\\-fig\\d+\\-v\\d+\\.jpg$", full.names = TRUE)
  #image_file_paths <- list.files(path = "~/Downloads/color", pattern = "jpeg$", full.names = TRUE)
  
  if (length(image_file_paths) == 0) {
    print(paste0("No figures for article ", article_id))
    next
  }
  
  for (image_file_path in image_file_paths) {
    print(paste0("Processing ", image_file_path))
    
    # Read in the normal vision image
    img <- image_read(image_file_path)
    
    is_rgb <- image_info(img) %>%
      filter(colorspace == "sRGB") %>%
      nrow() > 0

    if (!is_rgb)
      next
    
    scale_height_pixels = 300
    max_colors = 256
    #max_colors = 16

    img = image_scale(img, geometry_size_pixels(height = scale_height_pixels))
    img = image_quantize(img, max = max_colors, colorspace = 'rgb')
    
    # The first dimension has RGB codes.
    # The second dimension is the width.
    # The third dimension is the height.
    img_data = image_data(img, channels="rgb")[,,]
    
    # Extract channels
    r = img_data[1,,]
    g = img_data[2,,]
    b = img_data[3,,]
    
    # Create tibble that has hex values and additional information
    img_tbl = tibble(r = as.vector(r), g = as.vector(g), b = as.vector(b)) %>%
      mutate(original_hex = str_c("#", str_to_upper(str_c(r, g, b)))) %>%
      mutate(deut_hex = deutan(original_hex, severity=1)) %>%
      mutate(is_gray = (r == g & g == b)) %>%
      mutate(deut_delta = find_hex_deltas(original_hex, deut_hex))
    
    # Save modified versions of images
    original_hex = pull(img_tbl, original_hex)
    original_img = convert_hex_vector_to_image(original_hex, dim(img_data))
    deut_hex = pull(img_tbl, deut_hex)
    deut_img = convert_hex_vector_to_image(deut_hex, dim(img_data))
    
    out_dir_path = paste0(modimages_dirpath, "/", sub(".jpg", "", basename(image_file_path)))
    dir.create(out_dir_path, recursive = TRUE, showWarnings = FALSE)
    image_write(original_img, paste0(out_dir_path, "/original.jpg"), quality = 100)
    image_write(deut_img, paste0(out_dir_path, "/deut.jpg"), quality = 100)

    # Calculate ratios between all color pairs
    # https://vis4.net/blog/2018/02/automate-colorblind-checking/
    deut_ratios = find_color_ratios(original_hex)
    
    # Find color pair with highest ratio
    max_ratio_hex_pair = extract_ratio_hex_pair(deut_ratios, 1)
    max_ratio = deut_ratios[paste0(max_ratio_hex_pair, collapse="_")]
    
    high_deut_ratios = sort(deut_ratios[deut_ratios > ratio_threshold], decreasing = TRUE)
    
    high_deut_colors = sapply(names(high_deut_ratios), function(x) {str_split(x, "_")[[1]]}) %>% as.vector() %>% unique()
    proportion_high_deut_ratio_pixels = filter(img_tbl, original_hex %in% high_deut_colors) %>%
      nrow() %>%
      `/`(nrow(img_tbl))
    
    # # Create images that highlight the color pairs that have high ratios
    # unlink(list.files(path = out_dir_path, pattern = "deut_masked_.+.jpg", full.names=TRUE))
    # if (length(high_deut_ratios) > 0) {
    #   for (i in 1:length(high_deut_ratios)) {
    #     hex_pair = extract_ratio_hex_pair(high_deut_ratios, i)
    #     
    #     pixels_affected_1 = which(original_hex == hex_pair[1])
    #     pixels_affected_2 = which(original_hex == hex_pair[2])
    #     proportion_pixels_affected = length(pixels_affected) / length(original_hex)
    # 
    #     if ((length(pixels_affected_1) / length(original_hex)) < 0.0001 | (length(pixels_affected_1) / length(original_hex)) < 0.0001)
    #       next
    #     
    #     deut_hex_masked = mask_hex_vector(original_hex, hex_pair[1], hex_pair[2])
    #     deut_img_masked = convert_hex_vector_to_image(deut_hex_masked, dim(img_data))
    #     
    #     out_file_path = paste0(out_dir_path, "/deut_masked_", paste0(hex_pair, collapse="_"), "_", round(high_deut_ratios[i], 1), ".jpg")
    #     image_write(deut_img_masked, out_file_path, quality = 100)
    #   }
    # }
    
    # Calculate the mean delta between original and deut image.
    mean_deut_delta = filter(img_tbl, !is_gray) %>%
      pull(deut_delta) %>%
      mean()
    
    # For the color pairs that have the highest ratios, what is the average Euclidean distance between them?
    original_hex_matrix = create_hex_matrix(original_hex, dim(img_data))
    distance_metrics = c()
    for (hex_pair in names(high_deut_ratios)) {
      hex1 = str_split(hex_pair, "_")[[1]][1]
      hex2 = str_split(hex_pair, "_")[[1]][2]
      #print(paste0("Finding euclidean distances for ", hex1, " and ", hex2))

      distances = get_euclidean_distances(original_hex_matrix, hex1, hex2)
      # Get the smallest distances and then calculate a summary statistic
      distances = sort(distances)[1:ceiling(length(distances) * 0.1)]
      distance_metrics = c(distance_metrics, median(distances, na.rm=TRUE))
    }
    
    # Take the smallest value and use as a combined metric.
    img_scores <- tibble(image = basename(image_file_path), max_ratio, num_high_ratio_colors = length(high_deut_ratios), proportion_high_deut_ratio_pixels, mean_deut_delta, euclidean_distance_metric = min(distance_metrics, na.rm = TRUE))

    if (is.null(scores_tbl)) {
      scores_tbl <- img_scores
    } else {
      scores_tbl <- bind_rows(scores_tbl, img_scores)
    }
#break
  }
#break
}

write_tsv(scores_tbl, metrics_filepath)

#TODO:
#  Scale to many more images and plot the metrics.
#    Calculate the metrics with smaller/larger size...with/without scaling...different numbers of colors. How correlated are the metrics?
#  Curate images and implement logic for estimating how accurate the automated approach is.

#https://webaim.org/contact/ (Cyndi Rowland, PhD, Utah State Univ.)