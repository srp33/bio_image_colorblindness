#! /bin/bash

set -o errexit

#Rscript /shared_dir/1_Parse_Articles_from_XML.R
#Rscript /shared_dir/2_Process_Images.R

Rscript /shared_dir/3_Sample_Images.R
rm -f ImageSample1000.zip
zip ImageSample1000.zip ImageSample1000/ -r
