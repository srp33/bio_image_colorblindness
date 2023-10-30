# This code only needs to be run once.
install.packages(c("colorspace", "doParallel", "foreach", "knitr", "grid", "magick", "spacesXYZ", "tidyverse", "xml2", "yardstick"), repos="https://cloud.r-project.org")

library(colorspace)
library(doParallel)
library(foreach)
library(grid)
library(knitr)
library(magick)
library(spacesXYZ)
library(tidyverse)
library(xml2)
library(yardstick)

# Show package versions.
sessionInfo()
