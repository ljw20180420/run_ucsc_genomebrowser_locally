#!/bin/bash

hub_dir="${HOME}/sdb1/myHub"

config_docker_build_and_run_proxy() {
    local port=$1

    mv ~/.docker/config.json ~/.docker/config.json.bak
    jq -s '.[0] * .[1]' ~/.docker/config.json.bak - \
        > ~/.docker/config.json \
        << EOF
{
    "proxies": {
            "default": {
            "httpProxy": "http://127.0.0.1:${port}",
            "httpsProxy": "http://127.0.0.1:${port}",
            "noProxy": "localhost,127.0.0.1/8"
        }
    }
}
EOF
}

config_docker_daemon_proxy() {
    local port=$1

    mv ~/.config/docker/daemon.json ~/.config/docker/daemon.json.bak
    jq -s '.[0] * .[1]' ~/.config/docker/daemon.json.bak - \
        > ~/.config/docker/daemon.json \
        << EOF
{
    "proxies": {
        "http-proxy": "http://127.0.0.1:${port}",
        "https-proxy": "http://127.0.0.1:${port}",
        "no-proxy": "localhost,127.0.0.0/8"
    }
}
EOF
}

config() {
    local port=$1

    config_docker_build_and_run_proxy ${port}
    config_docker_daemon_proxy ${port}
    systemctl --user daemon-reload
    systemctl --user restart docker
}

build() {
    if ! [ -f Dockerfile ]
    then
        wget https://raw.githubusercontent.com/ucscGenomeBrowser/kent/master/src/product/installer/docker/Dockerfile
    fi
    docker build . \
        --network=host \
        -t ljw/ucsc_genomebrowser_image
}

run() {
    if [ "$(docker ps -aq -f name=^/ucsc_genomebrowser$)" ]; then
        echo "Container exists. Starting it..."
        docker start ucsc_genomebrowser
    else
        echo "Container does not exist. Creating and running a new one..."
        docker run -d \
            --name ucsc_genomebrowser \
            -p 8080:80 \
            ljw/ucsc_genomebrowser_image \
            /sbin/my_init \
            --skip-startup-files
    fi
}

stop() {
    docker stop ucsc_genomebrowser
}

update() {
    docker exec ucsc_genomebrowser /bin/bash /root/browserSetup.sh cgiUpdate
}

shell() {
    docker exec -it ucsc_genomebrowser /bin/bash
}

inspect() {
    docker run --rm -it \
        ljw/ucsc_genomebrowser_image \
	/bin/bash
}

cwget() {
    local url=$1
    local output=$2
    if ! [ -f "${output}" ]
    then
        wget "${url}" \
            -O "${output}"
    fi
}

hub() {
    cwget "https://hgdownload.soe.ucsc.edu/gbdb/mm10/encode4/regulation/organAve/embryoCTCFAll.bw" "${hub_dir}/mm10/embryoCTCFAll.bw"
    cwget "https://hgdownload.soe.ucsc.edu/goldenPath/mm10/database/refGene.txt.gz" "${hub_dir}/mm10/refGene.txt.gz"

    genePredToBigGenePred refGene.txt.gz refGene.bgp
    gtfToGenePred
    genePredToBigGenePred
}

# config 6789
# build

cmd=$1
shift
"${cmd}" "$@"
