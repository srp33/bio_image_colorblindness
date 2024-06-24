remove_black_white_gray <- function(hex) {
  tibble(r = str_sub(hex, 2, 3),
               g = str_sub(hex, 4, 5),
               b = str_sub(hex, 6, 7)) %>%
    filter(r != g | g != b | r != b) %>%
    mutate(rgb = str_c("#", r, g, b)) %>%
    pull(rgb) %>%
    return()
}

convert_hex_vector_to_image <- function(hex, dimensions) {
  x = col2rgb(hex)
  
  r = matrix(as.raw(x[1,]), nrow=dimensions[2], ncol=dimensions[3])
  g = matrix(as.raw(x[2,]), nrow=dimensions[2], ncol=dimensions[3])
  b = matrix(as.raw(x[3,]), nrow=dimensions[2], ncol=dimensions[3])
  
  y = array(raw(0), dim = dimensions)
  y[1,,] = r
  y[2,,] = g
  y[3,,] = b
  
  image_read(y, density="300x300") %>%
    image_convert(format = "jpeg", colorspace = "RGB") %>%
    return()
}

find_hex_deltas <- function(hex1, hex2, metric_year=2000) {
  # Finding delta is somewhat slow, so we only do it for unique pairs.

  hex_pairs = paste0(hex1, "_", hex2)
  uniq_hex_pairs = unique(hex_pairs)
  
  deltas = c()

  for (pair in uniq_hex_pairs) {
    pair_hex1 = str_sub(pair, 1, 7)
    pair_hex2 = str_sub(pair, 9, 15)
    
    deltas = c(deltas, find_hex_delta(pair_hex1, pair_hex2))
  }

  names(deltas) = uniq_hex_pairs
  
  return(deltas[hex_pairs])
}

find_hex_delta <- function(hex1, hex2, metric_year=2000) {
  rgb1 = hex2RGB(hex1)@coords
  rgb2 = hex2RGB(hex2)@coords
  
  return(abs(spacesXYZ::DeltaE(rgb1, rgb2, metric=metric_year)))
}

find_color_ratios <- function(hex) {
  hex = remove_black_white_gray(unique(hex))
  
  hex_pairs = c()
  ratios = c()
  
  for (hex1 in hex) {
    for (hex2 in hex) {
      if (hex1 == hex2)
        next
      
      hex_pair = paste0(sort(c(hex1, hex2)), collapse="_")
      
      if (hex_pair %in% hex_pairs)
        next
      
      hex_pairs = c(hex_pairs, hex_pair)
      
      orig_delta = find_hex_delta(hex1, hex2)
      deut_delta = find_hex_delta(deutan(hex1, severity=0.8), deutan(hex2, severity=0.8))
      
      ratio = NA
      
      if (deut_delta != 0)
        ratio = orig_delta / deut_delta
      
      ratios = c(ratios, ratio)
    }
  }
  
  names(ratios) = hex_pairs
  return(ratios)
}

extract_ratio_hex_pair <- function(hex_ratios, sorted_i) {
  max_ratio_hex_pair = sort(hex_ratios, decreasing=TRUE)[sorted_i]
  hex1 = str_split(names(max_ratio_hex_pair), "_")[[1]][1]
  hex2 = str_split(names(max_ratio_hex_pair), "_")[[1]][2]
  
  return(c(hex1, hex2))
}

mask_hex_vector <- function(hex_vector, hex1, hex2) {
  hex_vector[which(hex_vector == hex1)] = hex1
  hex_vector[which(hex_vector == hex2)] = hex2
  hex_vector[which(hex_vector != hex1 & hex_vector != hex2)] = "#FFFFFF"
  
  return(hex_vector)
}

create_hex_matrix <- function(hex, img_dim) {
  matrix(hex, nrow = img_dim[2], byrow = TRUE)
}

get_euclidean_distances = function(hex_matrix, hex1, hex2) {
  color1_positions = NULL
  color2_positions = NULL
  
  for (row in 1:nrow(hex_matrix)) {
    col = which(hex_matrix[row,] == hex1)
    if (length(col) > 0) {
      color1_positions = rbind(color1_positions, cbind(row, col))
    }
    
    col = which(hex_matrix[row,] == hex2)
    if (length(col) > 0) {
      color2_positions = rbind(color2_positions, cbind(row, col))
    }
  }
  
#  if (length(color1_positions) <= 3 | length(color2_positions) <= 3) {
#    return(NA)
#  }
  
  parse_positions <- function(positions, row_indices, col_index) {
    positions[row_indices,col_index]
  }
  
  # It's fairly expensive to invoke parse_positions so many times.
  # Perhaps we can find a faster way to do it.
  expand.grid(1:nrow(color1_positions), 1:nrow(color2_positions)) %>%
    as_tibble() %>%
    mutate(Color1_x = parse_positions(color1_positions, Var1, 1)) %>%
    mutate(Color1_y = parse_positions(color1_positions, Var1, 2)) %>%
    mutate(Color2_x = parse_positions(color2_positions, Var2, 1)) %>%
    mutate(Color2_y = parse_positions(color2_positions, Var2, 2)) %>%
    select(-Var1, -Var2) %>%
    mutate(distance = euclidean_dist(Color1_x, Color2_x, Color1_y, Color2_y)) %>%
    pull(distance) %>%
    return()
}

euclidean_dist = function(x1, x2, y1, y2) {
  sqrt((x2 - x1)^2 + (y2 - y1)^2)
}

process_article = function(article_id, article_dirpath, results_file_path, ratio_threshold) {
  if (file.exists(results_file_path))
      return(paste0("Already saved - ", results_file_path))

  # Gets path to images inside an article's directory
  image_file_paths <- list.files(path = article_dirpath, pattern = "elife\\-\\d{5}\\-fig\\d+\\-v\\d+\\.jpg$", full.names = TRUE)

  if (length(image_file_paths) == 0)
      return(paste0("No images - ", results_file_path))

  scores_tbl = NULL
  for (image_file_path in image_file_paths) {
      img_scores = NULL

      tryCatch(
          expr = { img_scores = calculate_image_metrics(article_id, image_file_path, ratio_threshold) },
          error = function(e) { exc = e },
          warning = function(w) { }
      )

      if (is.null(img_scores)) {
          next
      }

      if (is.null(scores_tbl)) {
          scores_tbl <- img_scores
      } else {
          scores_tbl <- bind_rows(scores_tbl, img_scores)
      }
  }

  if (is.null(scores_tbl)) {
      return(paste0("Error occurred so that no valid images were found - ", results_file_path))
  } else {
      write_tsv(scores_tbl, results_file_path)
      return(paste0("Saved - ", results_file_path))
  }
}

calculate_image_metrics = function(article_id, image_file_path, ratio_threshold) {
  # Read in the normal vision image
  img <- image_read(image_file_path)

  is_cmyk <- image_info(img) %>%
    filter(colorspace == "CMYK") %>%
    nrow() > 0
  
  if (is_cmyk) {
    img <- image_convert(img, colorspace="srgb")
  }
  
  is_rgb <- image_info(img) %>%
    filter(colorspace == "sRGB") %>%
    nrow() > 0

  if (!is_rgb)
    return(tibble(article_id, image_file_path, is_rgb = 0, max_ratio = NA, num_high_ratios = NA, proportion_high_ratio_pixels = NA, mean_delta = NA, euclidean_distance_metric = NA))
    
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
    mutate(deut_hex = deutan(original_hex, severity=0.8)) %>%
    mutate(is_gray = (r == g & g == b)) %>%
    mutate(deut_delta = find_hex_deltas(original_hex, deut_hex))
    
  # Save modified versions of images
  original_hex = pull(img_tbl, original_hex)

  # Calculate ratios between all color pairs
  # https://vis4.net/blog/2018/02/automate-colorblind-checking/
  deut_ratios = find_color_ratios(original_hex)

  # If this comes back as NULL, it means all the colors were grayscale,
  # even though the image was marked as RGB.
  if (is.null(deut_ratios)) {
    return(tibble(article_id, image_file_path, is_rgb = 0, max_ratio = NA, num_high_ratios = NA, proportion_high_ratio_pixels = NA, mean_delta = NA, euclidean_distance_metric = NA))
  }

  # Find color pair with highest ratio
  max_ratio_hex_pair = extract_ratio_hex_pair(deut_ratios, 1)
  max_ratio = deut_ratios[paste0(max_ratio_hex_pair, collapse="_")]

  high_deut_ratios = sort(deut_ratios[deut_ratios > ratio_threshold], decreasing = TRUE)

  high_deut_colors = sapply(names(high_deut_ratios), function(x) {str_split(x, "_")[[1]]}) %>% as.vector() %>% unique()
  proportion_high_ratio_pixels = filter(img_tbl, original_hex %in% high_deut_colors) %>%
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
  mean_delta = filter(img_tbl, !is_gray) %>%
    pull(deut_delta) %>%
    mean()
    
  # For the color pairs that have the highest ratios, what is the average Euclidean distance between them?
  if (length(high_deut_ratios) == 0) {
    euclidean_distance_metric = NA
  } else {
    original_hex_matrix = create_hex_matrix(original_hex, dim(img_data))
    distance_metrics = c()

    for (hex_pair in names(high_deut_ratios)) {
      hex1 = str_split(hex_pair, "_")[[1]][1]
      hex2 = str_split(hex_pair, "_")[[1]][2]

      distances = get_euclidean_distances(original_hex_matrix, hex1, hex2)

      # Get the smallest distances and then calculate a summary statistic
      distances = sort(distances)[1:ceiling(length(distances) * 0.1)]
      distance_metrics = c(distance_metrics, median(distances, na.rm=TRUE))
    }

    euclidean_distance_metric = min(distance_metrics, na.rm = TRUE)
  }

  return(tibble(article_id, image_file_path, is_rgb = 1, max_ratio, num_high_ratios = length(high_deut_ratios), proportion_high_ratio_pixels, mean_delta, euclidean_distance_metric = euclidean_distance_metric))
}

create_simulated_image = function(in_file_path, out_file_path) {
  # Read in the normal vision image
  img <- image_read(in_file_path)

  # The first dimension has RGB codes.
  # The second dimension is the width.
  # The third dimension is the height.
  img_data = NULL
  tryCatch(
    expr = {
        img_data = image_data(img, channels="rgb")[,,]
    },
    error = function(e) {
        img = image_convert(img, colorspace="rgb")
        img_data = image_data(img, channels="rgb")[,,]
    },
    warning = function(w) { }
  )

  # This happens when there is a corrupt image file
  if (is.null(img_data))
      return(NULL)

  # Extract channels
  r = img_data[1,,]
  g = img_data[2,,]
  b = img_data[3,,]
    
  # Create tibble that has hex values and additional information
  img_tbl = tibble(r = as.vector(r), g = as.vector(g), b = as.vector(b)) %>%
    mutate(original_hex = str_c("#", str_to_upper(str_c(r, g, b)))) %>%
    mutate(deut_hex = deutan(original_hex, severity=0.8))
    
  # Save modified versions of images
  deut_hex = pull(img_tbl, deut_hex)
  deut_img = convert_hex_vector_to_image(deut_hex, dim(img_data))
    
  out_dir_path = dirname(out_file_path)
  dir.create(out_dir_path, recursive = TRUE, showWarnings = FALSE)

  image_write(deut_img, out_file_path, quality = 100)
}

plot_probabilities = function(predictions, out_file_name) {
  p = ggplot(predictions, aes(x = label, y = probability_unfriendly, col = label)) +
    geom_boxplot(outlier.shape = NA) +
    geom_jitter(height = 0, alpha = 0.3, size = 3) +
    theme_bw(base_size = 16) +
    guides(color = FALSE) +
    xlab("") +
    ylab("Confidence score (Definitely problematic)") +
    scale_color_manual(values = c("#018571", "#a6611a"))
  
  plot(p)
  save_fig(out_file_name)
}

plot_roc = function(predictions, out_file_name) {
  r = roc(label ~ probability_unfriendly, data = predictions)
  
  plot_data = tibble(Sensitivity = r$sensitivities, Specificity = r$specificities, Threshold = r$thresholds) %>%
    arrange(Sensitivity, desc(Specificity))

  p = ggplot(plot_data, aes(x = Specificity, y = Sensitivity)) +
    geom_line() +
    geom_segment(aes(x = 1, xend = 0, y = 0, yend = 1), color = "grey", linetype = "dashed") +
    scale_y_continuous(expand = c(0, 0)) +
    scale_x_reverse(expand = c(0, 0)) +
    geom_text(aes(x = 0.3, y = 0.3, label = paste0("AUROC: ", round(as.numeric(r$auc), 2)))) +
    theme_bw(base_size = 12) +
    theme(plot.margin = margin(t = 5.5, r = 12, b = 5.5, l = 5.5))
  
  plot(p)
  save_fig(out_file_name)
}

plot_prc = function(predictions, out_file_name) {
  pr_curve <- pr.curve(scores.class0 = predictions$probability_unfriendly, weights.class0 = predictions$label == "Definitely problematic", curve = TRUE)
  
  auprc = pr_curve$auc.integral
  
  plot_data = as_tibble(pr_curve$curve) %>%
    dplyr::rename(Recall = V1, Precision = V2, Threshold = V3)
  
  p = ggplot(plot_data, aes(x = Recall, y = Precision)) +
    geom_line() +
    geom_text(x = 0.3, y = 0.3, label = paste0("AUPRC: ", round(auprc, 2))) +
    xlim(0, 1) +
    ylim(0, 1) +
    theme_bw()
  
  plot(p)
  
  save_fig(out_file_name)
}

save_fig = function(file_name, width = 6.5, height=5) {
  ggsave(paste0("Figures/", file_name, ".png"), width=width, height=height)
  ggsave(paste0("Figures/", file_name, ".pdf"), width=width, height=height)
}