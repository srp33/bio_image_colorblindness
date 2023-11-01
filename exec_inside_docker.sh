#! /bin/bash

set -o errexit

#git clone https://github.com/elifesciences/elife-article-xml.git

#Rscript 0_Show_Package_Versions.R
#Rscript 1_Parse_Articles_from_XML.R

# These images were identified in step 3 as being corrupted.
# We move them here so that they will be handled properly at step 2.

#mv Images/00640/elife-00640-fig6-v1.jpg Images/00640/elife-00640-fig6-v1_corrupted.jpg 
#mv Images/12717/elife-12717-fig5-v2.jpg Images/12717/elife-12717-fig5-v2_corrupted.jpg
#mv Images/14320/elife-14320-fig2-v1.jpg Images/14320/elife-14320-fig2-v1_corrupted.jpg
#mv Images/26163/elife-26163-fig4-v2.jpg Images/26163/elife-26163-fig4-v2_corrupted.jpg
#mv Images/26376/elife-26376-fig3-v2.jpg Images/26376/elife-26376-fig3-v2_corrupted.jpg
#mv Images/64041/elife-64041-fig6-v2.jpg Images/64041/elife-64041-fig6-v2_corrupted.jpg

#wget -O Images/00640/elife-00640-fig6-v1.jpg https://iiif.elifesciences.org/lax/00640%2Felife-00640-fig6-v1.tif/full/1500,/0/default.jpg
#wget -O Images/12717/elife-12717-fig5-v2.jpg https://iiif.elifesciences.org/lax/12717%2Felife-12717-fig5-v2.tif/full/1500,/0/default.jpg
#wget -O Images/14320/elife-14320-fig2-v1.jpg https://iiif.elifesciences.org/lax/14320%2Felife-14320-fig2-v1.tif/full/1500,/0/default.jpg
#wget -O Images/26163/elife-26163-fig4-v2.jpg https://iiif.elifesciences.org/lax/26163%2Felife-26163-fig4-v2.tif/full/,1500/0/default.jpg
#wget -O Images/26376/elife-26376-fig3-v2.jpg https://iiif.elifesciences.org/lax/26376%2Felife-26376-fig3-v2.tif/full/,1500/0/default.jpg
#wget -O Images/64041/elife-64041-fig6-v2.jpg https://iiif.elifesciences.org/lax/64041%2Felife-64041-sa2-fig1-v2.tif/full/full/0/default.jpg

#Rscript 2_Process_Images.R

# I ran this before we had the most recent collection of images, so it is not fully reproducible.
#Rscript 3A_Sample_Images.R 1000 "ImageSample1000" "ImageSample1000_Metrics.tsv" NULL

#Rscript 3A_Sample_Images.R 4000 "ImageSample1001to5000" "ImageSample1001to5000_Metrics.tsv" "ImageSample1000_Metrics.tsv"
#Rscript 3A_Sample_Images.R 1000 "ImageSample5001to6000" "ImageSample5001to6000_Metrics.tsv" "ImageSample1000_Metrics.tsv.gz" "ImageSample1001to5000_Metrics.tsv.gz"

# Combine first 1000 with subsequent 4000 images.
#mkdir -p ImageSample1to5000
#cp -r ImageSample1000/* ImageSample1to5000/
#cp -r ImageSample1001to5000/* ImageSample1to5000/

# Identify images for which a simulated version could not be automatically created.
#for d in ImageSample1to5000/*
#do
#  if [ ! -f $d/deut.jpg ]
#  then
#    echo $d does not exist, need to manually download it.
#  fi
#done

#for d in ImageSample5001to6000/*
#do
#  if [ ! -f $d/deut.jpg ]
#  then
#    echo $d does not exist, need to manually download it.
#  fi
#done

#Rscript 3B_Process_Corrupted_Images.R

#python3 3C_Find_Other_Corrupted_Images.py
#NOTE: This didn't find any corrupted images.

#cp eLife_Metrics.tsv /tmp/eLife_Metrics.tsv
#python3 3D_Mark_Duplicates.py

#Rscript 4_Analyze_Image_Metrics.R
#python3 5_Assign_Cross_Validation_Folds.py
#python3 6_Classify_Using_Metrics.py

#python3 7A_Classify_Using_CNN.py
python3 7A_Classify_Using_CNN.py > /tmp/7A_Classify_Using_CNN.out 2> /tmp/7A_Classify_Using_CNN.err
#python3 7B_Collate_CNN_Metrics.py

#TODO: Build final model, save it, and apply it to the hold-out set.
