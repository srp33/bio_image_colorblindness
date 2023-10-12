# This code only needs to be run once.
install.packages(c("colorspace", "doParallel", "foreach", "grid", "magick", "spacesXYZ", "tidymodels", "tidyverse", "xml2", "yardstick"), repos="https://cloud.r-project.org")

library(colorspace)
library(doParallel)
library(foreach)
library(grid)
library(magick)
library(spacesXYZ)
library(tidymodels)
library(tidyverse)
library(xml2)
library(yardstick)

# Show package versions.
sessionInfo()