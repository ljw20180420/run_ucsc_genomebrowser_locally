#!/bin/bash

# change to the dir of the script
cd $( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

build() {
    if ! [ -f Dockerfile ]
    then
        wget https://raw.githubusercontent.com/ucscGenomeBrowser/kent/master/src/product/installer/docker/Dockerfile
    fi
    docker build . \
        --network=host \
        -t ljw/ucsc_genomebrowser_image
}

build
