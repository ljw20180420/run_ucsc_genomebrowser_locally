addGene() {
    local hub_dir=$1
    local genome=$2
    local url=$3

    cat <<EOF
track ${genome}Gene
bigDataUrl ${genome}.bb
shortLabel ${genome}Gene
longLabel ${genome}Gene
type bigGenePred
visibility pack

EOF

    if [[ -s "${hub_dir}/${genome}/${genome}.bb" ]]
    then
        return
    fi

    if [[ "${url}" == *".gtf.gz" ]]
    then
        _fetch "${url}" "${hub_dir}/${genome}/${genome}.gtf.gz"
        gzip -fkd "${hub_dir}/${genome}/${genome}.gtf.gz"
        gtfToGenePred "${hub_dir}/${genome}/${genome}.gtf" "${hub_dir}/${genome}/${genome}.gp"
    elif [[ "${url}" == *".gp.gz" ]]
    then
        _fetch "${url}" "${hub_dir}/${genome}/${genome}.gp.gz"
        gzip -fkd "${hub_dir}/${genome}/${genome}.gp.gz"
    elif [[ "${url}" == *".gtf" ]]
    then
        _fetch "${url}" "${hub_dir}/${genome}/${genome}.gtf"
        gtfToGenePred "${hub_dir}/${genome}/${genome}.gtf" "${hub_dir}/${genome}/${genome}.gp"
    elif [[ "${url}" == *".gp" ]]
    then
        _fetch "${url}" "${hub_dir}/${genome}/${genome}.gp"
    else
        echo "Unknow gene suffix" >&2
        exit 1
    fi
    _fetch "https://genome.ucsc.edu/goldenPath/help/examples/bigGenePred.as" "${hub_dir}/${genome}/bigGenePred.as"
    local line1=$(head -n1 "${hub_dir}/${genome}/${genome}.gp")
    if [[ "${line1}" =~ ^[0-9] ]]
    then
        local cnum=3
    else
        local cnum=2
    fi
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
track ${base}
bigDataUrl ${base}
shortLabel ${base}
longLabel ${base}
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
track ${base}
bigDataUrl ${base}
shortLabel ${base}
longLabel ${base}
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

    if [[ "${url}" != *".hic" && "${url}" == *".mcool" && "${url}" == *".cool" ]]
    then
        echo "Error: file extension must be .hic or .[m]cool"
        exit 1
    fi
    _fetch "${url}" "${hub_dir}/${genome}/${base}"
    if [[ "${url}" == *".mcool" || "${url}" == *".cool" ]]
    then
        if [[ ! -s "${hub_dir}/${genome}/${stem}.hic" ]]
        then
            hictk convert "${hub_dir}/${genome}/${base}" "${hub_dir}/${genome}/${stem}.hic"
        fi
    fi

    cat <<EOF
track ${stem}.hic
bigDataUrl ${stem}.hic
shortLabel ${stem}.hic
longLabel ${stem}.hic
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
    bedToBigBed -sort -fixScores \
        "${hub_dir}/${genome}/${base}" \
        "${hub_dir}/${genome}/${genome}.chrom.sizes" \
        "${hub_dir}/${genome}/${stem}.bb"

    cat <<EOF
track ${stem}.bb
bigDataUrl ${stem}.bb
shortLabel ${stem}.bb
longLabel ${stem}.bb
type bigBed 6 +
visibility dense

EOF
}

addNarrowPeak() {
    local hub_dir=$1
    local genome=$2
    local url=$3
    local base="${url##*/}"
    local stem="${base%.*}"

    _fetch "${url}" "${hub_dir}/${genome}/${base}"
    _fetch "https://genome.ucsc.edu/goldenpath/help/examples/bigNarrowPeak.as" "${hub_dir}/${genome}/bigNarrowPeak.as"
    bedToBigBed -sort -fixScores -type=bed6+4 -tab \
        -as="${hub_dir}/${genome}/bigNarrowPeak.as" \
        "${hub_dir}/${genome}/${base}" \
        "${hub_dir}/${genome}/${genome}.chrom.sizes" \
        "${hub_dir}/${genome}/${stem}.bb"

    cat <<EOF
track ${stem}.np
bigDataUrl ${stem}.bb
shortLabel ${stem}.np
longLabel ${stem}.np
type bigNarrowPeak
visibility dense

EOF
}
