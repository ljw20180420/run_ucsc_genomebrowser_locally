#!/bin/bash

. cfg.sh
. mm9.sh
. mm10.sh

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

hub() {
    mkdir -p "${hub_dir}"
    cp ./hub.txt "${hub_dir}/hub.txt"

    > "${hub_dir}/genomes.txt"
    mm10
    mm9
}

url() {
    # https://genome.ucsc.edu/goldenPath/help/assemblyHubHelp.html#linkingHub

    local hub_connect_page="http://localhost:8080/cgi-bin/hgHubConnect?hgHub_do_redirect=on&hgHubConnect.remakeTrackHub=on&hgHub_do_firstDb=1&hubUrl=http://localhost/myHub/hub.txt"

    echo ${hub_connect_page}
}

cmd=$1
shift
"${cmd}" "$@"
