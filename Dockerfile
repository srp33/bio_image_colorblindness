FROM bioconductor/bioconductor_docker:RELEASE_3_15

RUN R -e "install.packages(c('httr', 'magick', 'spacesXYZ', 'tidyverse', 'xml2'))"
RUN R -e "install.packages(c('foreach', 'doParallel'))"
# https://stackoverflow.com/questions/31407010/cache-resources-exhausted-imagemagick
RUN sed -i 's/1GiB/8GiB/g' /etc/ImageMagick-6/policy.xml

WORKDIR /shared_dir

ADD requirements.txt /shared_dir/
RUN python3 -m pip install --upgrade pip \
 && python3 -m pip install -r /shared_dir/requirements.txt

ADD *.sh /shared_dir/

ENTRYPOINT /shared_dir/exec_inside_docker.sh
ADD *.R /shared_dir/
