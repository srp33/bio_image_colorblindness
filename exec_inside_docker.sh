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

# Combine first 1000 with subsequent 4000 images.
#mkdir -p ImageSample1to5000
#cp -r ImageSample1000/* ImageSample1to5000/
#cp -r ImageSample1001to5000/* ImageSample1to5000/

# Identify images for which a simulated version could not be automatically created.
#for d in ImageSample1to5000/*
#do
#  if [ ! -f $d/deut.jpg ]
#  then
#    echo $d does not exist, need to manually download and store as $d/original_downloaded.jpg
#  fi
#done

#wget -O /shared_dir/ImageSample1to5000/elife-00640-fig6-v1/original_downloaded.jpg https://iiif.elifesciences.org/lax/00640%2Felife-00640-fig6-v1.tif/full/1500,/0/default.jpg
#wget -O /shared_dir/ImageSample1to5000/elife-12717-fig5-v2/original_downloaded.jpg https://iiif.elifesciences.org/lax/12717%2Felife-12717-fig5-v2.tif/full/1500,/0/default.jpg
#wget -O /shared_dir/ImageSample1to5000/elife-14320-fig2-v1/original_downloaded.jpg https://iiif.elifesciences.org/lax/14320%2Felife-14320-fig2-v1.tif/full/1500,/0/default.jpg
#wget -O /shared_dir/ImageSample1to5000/elife-26163-fig4-v2/original_downloaded.jpg https://iiif.elifesciences.org/lax/26163%2Felife-26163-fig4-v2.tif/full/,1500/0/default.jpg
#wget -O /shared_dir/ImageSample1to5000/elife-26376-fig3-v2/original_downloaded.jpg https://iiif.elifesciences.org/lax/26376%2Felife-26376-fig3-v2.tif/full/,1500/0/default.jpg
#wget -O /shared_dir/ImageSample1to5000/elife-64041-fig6-v2/original_downloaded.jpg https://iiif.elifesciences.org/lax/64041%2Felife-64041-sa2-fig1-v2.tif/full/full/0/default.jpg

#Rscript /shared_dir/2B_Process_Corrupted_Images.R

#python3 /shared_dir/2C_Find_Other_Corrupted_Images.py
#NOTE: This didn't find any corrupted images.

