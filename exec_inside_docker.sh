#! /bin/bash

set -o errexit

Rscript /shared_dir/1_Parse_Articles_from_XML.R
Rscript /shared_dir/2_Process_Images.R
