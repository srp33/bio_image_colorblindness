FROM bioconductor/bioconductor_docker:RELEASE_3_15

RUN R -e "install.packages(c('httr', 'magick', 'spacesXYZ', 'tidyverse', 'xml2'))"
RUN R -e "install.packages(c('foreach', 'doParallel'))"
# https://stackoverflow.com/questions/31407010/cache-resources-exhausted-imagemagick
RUN sed -i 's/1GiB/8GiB/g' /etc/ImageMagick-6/policy.xml

ADD *.sh /shared_dir/

WORKDIR /shared_dir
ENTRYPOINT /shared_dir/exec_inside_docker.sh

ADD *.R /shared_dir/
