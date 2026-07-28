#!/bin/bash

. cfg.sh

_config_docker_build_and_run_proxy() {
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

_config_docker_daemon_proxy() {
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
            -v ${hub_dir}:/usr/local/apache/htdocs/myHub \
            -v ${cfg}:/usr/local/apache/cgi-bin/hg.conf \
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

_cwget() {
    local url=$1
    local output=$2
    if ! [ -f "${output}" ]
    then
        wget "${url}" -O "${output}"
    fi
}

_ccp() {
    local path=$1
    local output=$2
    if ! [ -f "${output}" ]
    then
        cp "${path}" "${output}"
    fi
}

genomes() {
    local assembly=$1
    local organism=$2
    local defaultPos=$3
    cat >> "${hub_dir}/genomes.txt" \
        <<EOF
genome ${assembly}
trackDb ${assembly}/trackDb.txt
twoBitPath ${assembly}/${assembly}.2bit
chromSizes ${assembly}/${assembly}.chrom.sizes
organism ${organism}
defaultPos ${defaultPos}

EOF
}

addBigWig() {
    local assembly=$1
    local bigWig=$2
    local stem="${bigWig##*/}"
    stem="${stem%.*}"

    local bw_up="$(bigWigInfo -minMax "${hub_dir}/${assembly}/${bigWig}" | cut -d' ' -f2)"
    cat \
        >> "${hub_dir}/${assembly}/trackDb.txt" \
        <<EOF
track ${stem}
bigDataUrl ${bigWig}
shortLabel ${stem}
longLabel ${stem}
type bigWig 0 ${bw_up}
visibility full

EOF
}

genePredToBigBed() {
    local assembly=$1
    local genePred=$2
    local bigGenePred="${genePred%.*}.bgp"
    local bigBed="${genePred%.*}.bb"

    cut -f3- "${hub_dir}/${assembly}/${genePred}" |
    awk -F $'\t' -v OFS=$'\t' '
        {
            print $11,$0
        }
    ' |
    genePredToBigGenePred stdin stdout |
    sort -k1,1 -k2,2n \
        > "${hub_dir}/${assembly}/${bigGenePred}"
    bedToBigBed -type=bed12+8 -tab \
        -as="${hub_dir}/${assembly}/bigGenePred.as" \
        "${hub_dir}/${assembly}/${bigGenePred}" \
        "${hub_dir}/${assembly}/${assembly}.chrom.sizes" \
        "${hub_dir}/${assembly}/${bigBed}"
}

addBigGenePred() {
    local assembly=$1
    local bigBed=$2
    local stem="${bigBed##*/}"
    stem="${stem%.*}"

    cat \
        >> "${hub_dir}/${assembly}/trackDb.txt" \
        <<EOF
track ${stem}
bigDataUrl ${bigBed}
shortLabel ${stem}
longLabel ${stem}
type bigGenePred
visibility full

EOF
}

mm10() {
    _cwget "https://hgdownload.gi.ucsc.edu/goldenPath/mm10/bigZips/mm10.chrom.sizes" "${hub_dir}/lmm10/lmm10.chrom.sizes"
    _cwget "https://hgdownload.gi.ucsc.edu/goldenPath/mm10/bigZips/mm10.2bit" "${hub_dir}/lmm10/lmm10.2bit"
    genomes "lmm10" "Mus Musculus" "chr18:36900000-37900000"

    > "${hub_dir}/lmm10/trackDb.txt"

    _cwget "https://hgdownload.soe.ucsc.edu/gbdb/mm10/encode4/regulation/organAve/embryoCTCFAll.bw" "${hub_dir}/lmm10/embryoCTCFAll.bw"
    addBigWig "lmm10" "embryoCTCFAll.bw"

    _ccp "/home/ljw/sdc1/cpcdh/GSE235386/GSM7501570_esc_ctcf_1.bw" "${hub_dir}/lmm10/GSM7501570_esc_ctcf_1.bw"
    addBigWig "lmm10" "GSM7501570_esc_ctcf_1.bw"

    _cwget "https://hgdownload.soe.ucsc.edu/goldenPath/mm10/database/refGene.txt.gz" "${hub_dir}/lmm10/refGene.txt.gz"
    gzip -fkd "${hub_dir}/lmm10/refGene.txt.gz"
    _cwget "https://genome.ucsc.edu/goldenPath/help/examples/bigGenePred.as" "${hub_dir}/lmm10/bigGenePred.as"
    genePredToBigBed "lmm10" "refGene.txt"
    addBigGenePred "lmm10" "refGene.bb"
}

hub() {
    mkdir -p "${hub_dir}"
    cp ./hub.txt "${hub_dir}/hub.txt"

    > "${hub_dir}/genomes.txt"
    mm10
}

hub_url() {
    local assembly

    hub_connect_page="http://localhost:8080/cgi-bin/hgHubConnect?hgHub_do_redirect=on&hgHubConnect.remakeTrackHub=on&hgHub_do_firstDb=1&hubUrl=http://localhost/myHub/hub.txt"
    genome_gateway_page="http://genome.ucsc.edu/cgi-bin/hgGateway?genome=${assembly}&hubUrl=http://localhost/myHub/hub.txt"
    genome_browser_page="http://localhost:8080/cgi-bin/hgTracks?genome=${assembly}&hubUrl=http://localhost/myHub/hub.txt"
}

cmd=$1
shift
"${cmd}" "$@"
