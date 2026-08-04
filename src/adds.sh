addGene() {
    local hub_dir=$1
    local genome=$2
    local url=$3

    if [[ "${url}" == *".gz" ]]
    then
        _fetch "${url}" "${hub_dir}/${genome}/${genome}.gp.gz"
        gzip -fkd "${hub_dir}/${genome}/${genome}.gp.gz"
    else
        _fetch "${url}" "${hub_dir}/${genome}/${genome}.gp"
    fi
    _fetch "https://genome.ucsc.edu/goldenPath/help/examples/bigGenePred.as" "${hub_dir}/${genome}/bigGenePred.as"
    local line1=$(head -n1 "${hub_dir}/${genome}/${genome}.gp")
    if [[ "${line1}" =~ ^[0-9] ]]
    then
        local cnum=3
    else
        local cnum=2
    fi
    echo ${cnum} >&2
    cut -f${cnum}- "${hub_dir}/${genome}/${genome}.gp" |
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
    local url=$3
    local base="${url##*/}"
    local stem="${base%.*}"

    _fetch "${url}" "${hub_dir}/${genome}/${base}"

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
    local url=$3
    local base="${url##*/}"
    local stem="${base%.*}"

    _fetch "${url}" "${hub_dir}/${genome}/${base}"
    if [[ "${url}" != "https://"* && -s "${url}.bai" ]]
    then
        _fetch "${url}.bai" "${hub_dir}/${genome}/${base}.bai"
    else
        samtools index "${hub_dir}/${genome}/${base}"
    fi

    cat <<EOF
track ${stem}
bigDataUrl ${base}
shortLabel ${stem}
longLabel ${stem}
type bam
visibility hide

EOF
}

addHic() {
    local hub_dir=$1
    local genome=$2
    local url=$3
    local base="${url##*/}"
    local stem="${base%.*}"

    if [[ "${url}" == *".hic" ]]
    then
        _fetch "${url}" "${hub_dir}/${genome}/${base}"
    elif [[ "${url}" == *".mcool" || "${url}" == *".cool" ]]
    then
        if [[ ! -s "${hub_dir}/${genome}/${stem}.hic" ]]
        then
            apptainer run docker://ghcr.io/paulsengroup/hictk convert "${url}" "${hub_dir}/${genome}/${stem}.hic"
        fi
    else
        return
    fi

    cat <<EOF
track ${stem}
bigDataUrl ${stem}.hic
shortLabel ${stem}
longLabel ${stem}
type hic
visibility hide
autoScale on
drawMode triangle
normalization NONE
resolution Auto

EOF
}

addBed() {
    local hub_dir=$1
    local genome=$2
    local url=$3
    local base="${url##*/}"
    local stem="${base%.*}"

    _fetch "${url}" "${hub_dir}/${genome}/${base}"
    bedToBigBed -fixScores\
        "${hub_dir}/${genome}/${base}" \
        "${hub_dir}/${genome}/${genome}.chrom.sizes" \
        "${hub_dir}/${genome}/${stem}.bb"

    cat <<EOF
track ${stem}
bigDataUrl ${stem}.bb
shortLabel ${stem}
longLabel ${stem}
type bigBed 6 +
visibility full

EOF
}