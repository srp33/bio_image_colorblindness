#! /bin/bash

set -o errexit

#Rscript /shared_dir/1_Parse_Articles_from_XML.R
Rscript /shared_dir/2_Process_Images.R

#Rscript /shared_dir/X_Sample_Images.R
#rm -f ImageSample100.zip
#zip ImageSample100.zip ImageSample100/ -r
