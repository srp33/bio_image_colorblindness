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
      deut_delta = find_hex_delta(deutan(hex1, severity=1), deutan(hex2, severity=1))
      
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
  
  if (length(color1_positions) <= 3 | length(color2_positions) <= 3)
    return(NA)
  
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