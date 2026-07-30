#!/bin/bash

# change to the dir of the script
cd $( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

_fetch() {
    local url=$1
    local output=$2

    if ! [ -f "${output}" ]
    then
        if [[ "${url}" == "https://"* ]]
        then
            wget "${url}" -O "${output}"
        else
            cp "${url}" "${output}"
        fi
    fi
}

hubtxt() {
    local config=$1
    local hub
    local email

    read hub < <(jq -r '.hub' ${config})
    read email < <(jq -r '.email' ${config})
    cat <<EOF
hub ${hub}
shortLabel ${hub}
longLabel ${hub}
genomesFile genomes.txt
email ${email}

EOF
}

genomes() {
    local config=$1
    local hub_dir
    local genome
    local twoBitPath
    local chromSizes
    local organism
    local defaultPos
    local gene
    local bigWig

    read hub_dir < <(jq -r ".hub_dir" ${config})
    hub_dir=$(envsubst <<<${hub_dir})
    genome_num=$(jq '.genomes | length' ${config})
    for (( i = 0; i < ${genome_num}; ++i)) {
        read genome < <(jq -r ".genomes[${i}].genome" ${config})
        mkdir -p ${hub_dir}/${genome}

        read twoBitPath < <(jq -r ".genomes[${i}].twoBitPath" ${config})
        _fetch "${twoBitPath}" "${hub_dir}/${genome}/${genome}.2bit"
        read chromSizes < <(jq -r ".genomes[${i}].chromSizes" ${config})
        _fetch "${chromSizes}" "${hub_dir}/${genome}/${genome}.chrom.sizes"
        read organism < <(jq -r ".genomes[${i}].organism" ${config})
        read defaultPos < <(jq -r ".genomes[${i}].defaultPos" ${config})
        read gene < <(jq -r ".genomes[${i}].gene" ${config})
        cat <<EOF
genome ${genome}
trackDb ${genome}/trackDb.txt
twoBitPath ${genome}/${genome}.2bit
chromSizes ${genome}/${genome}.chrom.sizes
organism ${organism}
defaultPos ${defaultPos}

EOF

        > "${hub_dir}/${genome}/trackDb.txt"
        addGene ${hub_dir} ${genome} ${gene} >> "${hub_dir}/${genome}/trackDb.txt"

        if jq -r ".genomes[${i}].tracks | has(\"bigWig\")" ${config} > /dev/null
        then
            bigWig_num=$(jq -r ".genomes[${i}].tracks.bigWig | length" ${config})
            for (( j = 0; j < ${bigWig_num}; ++j )) {
                read bigWig < <(jq -r ".genomes[$i].tracks.bigWig[${j}]" ${config})
                addBigWig ${hub_dir} ${genome} ${bigWig} >> "${hub_dir}/${genome}/trackDb.txt"
            }
        fi

        if jq -r ".genomes[${i}].tracks | has(\"bam\")" ${config} > /dev/null
        then
            bam_num=$(jq -r ".genomes[${i}].tracks.bam | length" ${config})
            for (( j = 0; j < ${bam_num}; ++j )) {
                read bam < <(jq -r ".genomes[$i].tracks.bam[${j}]" ${config})
                addBam ${hub_dir} ${genome} ${bam} >> "${hub_dir}/${genome}/trackDb.txt"
            }
        fi
    }
}

addGene() {
    local hub_dir=$1
    local genome=$2
    local gene=$3

    if [[ "${gene}" == *".gz" ]]
    then
        _fetch "${gene}" "${hub_dir}/${genome}/${genome}.gp.gz"
        gzip -fkd "${hub_dir}/${genome}/${genome}.gp.gz"
    else
        _fetch "${gene}" "${hub_dir}/${genome}/${genome}.gp"
    fi
    _fetch "https://genome.ucsc.edu/goldenPath/help/examples/bigGenePred.as" "${hub_dir}/${genome}/bigGenePred.as"
    cut -f3- "${hub_dir}/${genome}/${genome}.gp" |
    awk -F $'\t' -v OFS=$'\t' '
        {
            print $11,$0
        }
    ' |
    genePredToBigGenePred stdin stdout |
    sort -k1,1 -k2,2n \
        > "${hub_dir}/${genome}/${genome}.bgp"
    bedToBigBed -type=bed12+8 -tab \
        -as="${hub_dir}/${genome}/bigGenePred.as" \
        "${hub_dir}/${genome}/${genome}.bgp" \
        "${hub_dir}/${genome}/${genome}.chrom.sizes" \
        "${hub_dir}/${genome}/${genome}.bb"

    cat <<EOF
track ${genome}Gene
bigDataUrl ${genome}.bb
shortLabel ${genome}Gene
longLabel ${genome}Gene
type bigGenePred
visibility full

EOF
}

addBigWig() {
    local hub_dir=$1
    local genome=$2
    local bigWig=$3
    local base="${bigWig##*/}"
    local stem="${base%.*}"

    _fetch "${bigWig}" "${hub_dir}/${genome}/${base}"
    local bw_up="$(bigWigInfo -minMax "${hub_dir}/${genome}/${base}" | cut -d' ' -f2)"
    cat <<EOF
track ${stem}
bigDataUrl ${base}
shortLabel ${stem}
longLabel ${stem}
type bigWig 0 ${bw_up}
visibility full
autoScale on

EOF
}

addBam() {
    local hub_dir=$1
    local genome=$2
    local bam=$3
    local base="${bam##*/}"
    local stem="${base%.*}"

    _fetch "${bam}" "${hub_dir}/${genome}/${base}"
    cat <<EOF
track ${stem}
bigDataUrl ${base}
shortLabel ${stem}
longLabel ${stem}
type bam
visibility hide

EOF
}

url() {
    # https://genome.ucsc.edu/goldenPath/help/assemblyHubHelp.html#linkingHub

    local hub_connect_page="http://localhost:8080/cgi-bin/hgHubConnect?hgHub_do_redirect=on&hgHubConnect.remakeTrackHub=on&hgHub_do_firstDb=1&hubUrl=http://localhost/myHub/hub.txt"

    echo ${hub_connect_page}
}

main() {
    local config=$1

    read hub_dir < <(jq -r '.hub_dir' ${config})
    hub_dir=$(envsubst <<<${hub_dir})
    mkdir -p ${hub_dir}

    hubtxt ${config} > ${hub_dir}/hub.txt

    genomes ${config} > ${hub_dir}/genomes.txt
}

main config.json
