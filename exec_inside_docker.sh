#! /bin/bash

set -o errexit

#Rscript /shared_dir/0_Show_Package_Versions.R
#Rscript /shared_dir/1_Parse_Articles_from_XML.R
#Rscript /shared_dir/2_Process_Images.R

# I ran this before we had the most recent collection of images, so it is not fully reproducible.
#Rscript /shared_dir/3_Sample_Images.R 1000 "ImageSample1000" "ImageSample1000_Metrics.tsv" NULL
#rm -f ImageSample1000.zip
#zip ImageSample1000.zip ImageSample1000/ -r

#Rscript /shared_dir/3_Sample_Images.R 4000 "ImageSample1001to5000" "ImageSample1001to5000_Metrics.tsv" "ImageSample1000_Metrics.tsv"
#rm -f ImageSample1001to5000.zip
#zip ImageSample1001to5000.zip ImageSample1001to5000/ -r

#gzip ImageSample1000_Metrics.tsv
#gzip ImageSample1001to5000_Metrics.tsv

#Rscript /shared_dir/3_Sample_Images.R 1000 "ImageSample5001to6000" "ImageSample5001to6000_Metrics.tsv" "ImageSample1000_Metrics.tsv.gz" "ImageSample1001to5000_Metrics.tsv.gz"
#rm -f ImageSample5001to6000.zip
#zip ImageSample5001to6000.zip ImageSample5001to6000/ -r

#gzip ImageSample5001to6000_Metrics.tsv
