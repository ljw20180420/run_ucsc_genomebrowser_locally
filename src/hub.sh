#!/bin/bash

# change to the dir of the script
cd $( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

_fetch() {
    local url=$1
    local output=$2

    if ! [ -s "${output}" ]
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
description ${organism}

EOF

        > "${hub_dir}/${genome}/trackDb.txt"
        addGene ${hub_dir} ${genome} ${gene} >> "${hub_dir}/${genome}/trackDb.txt"

        for type in bigWig bam hic bed
        do
            if jq -r ".genomes[${i}].tracks | has(\"${type}\")" ${config} > /dev/null
            then
                num=$(jq -r ".genomes[${i}].tracks.${type} | length" ${config})
                for (( j = 0; j < ${num}; ++j )) {
                    read url < <(jq -r ".genomes[$i].tracks.${type}[${j}]" ${config})
                    "add${type^}" ${hub_dir} ${genome} ${url} >> "${hub_dir}/${genome}/trackDb.txt"
                }
            fi
        done
    }
}

main() {
    local config=$1

    read hub_dir < <(jq -r '.hub_dir' ${config})
    hub_dir=$(envsubst <<<${hub_dir})
    mkdir -p ${hub_dir}

    hubtxt ${config} > ${hub_dir}/hub.txt

    genomes ${config} > ${hub_dir}/genomes.txt
}

. adds.sh
main config.json
