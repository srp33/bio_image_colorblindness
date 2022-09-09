FROM bioconductor/bioconductor_docker:RELEASE_3_15

RUN R -e "install.packages(c('httr', 'magick', 'spacesXYZ', 'tidyverse', 'xml2'))"
RUN R -e "install.packages(c('foreach', 'doParallel'))"

ADD *.sh /shared_dir/

WORKDIR /shared_dir
ENTRYPOINT /shared_dir/exec_inside_docker.sh

ADD *.R /shared_dir/
