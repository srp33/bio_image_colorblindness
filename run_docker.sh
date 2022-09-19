#! /bin/bash

image_name="srp33/bio_image_colorblindness"
version=1
container_name="bio_image_colorblindness"

docker build -t ${image_name}:version$(cat VERSION) \
             -t ${image_name}:latest \
             .

mkdir -p TempResults

#  -i -t \
docker run \
  -d \
  --rm \
  --name ${container_name} \
  --user $(id -u):$(id -g) \
  -v $(pwd):/shared_dir \
  -v /tmp:/tmp \
  ${image_name}
