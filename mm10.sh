mm10() {
    _cwget "https://hgdownload.gi.ucsc.edu/goldenPath/mm10/bigZips/mm10.chrom.sizes" "${hub_dir}/lmm10/lmm10.chrom.sizes"
    _cwget "https://hgdownload.gi.ucsc.edu/goldenPath/mm10/bigZips/mm10.2bit" "${hub_dir}/lmm10/lmm10.2bit"
    genomes "lmm10" "Mus Musculus (mm10)" "chr18:36900000-37900000"

    > "${hub_dir}/lmm10/trackDb.txt"

    _cwget "https://hgdownload.soe.ucsc.edu/gbdb/mm10/encode4/regulation/organAve/embryoCTCFAll.bw" "${hub_dir}/lmm10/embryoCTCFAll.bw"
    addBigWig "lmm10" "embryoCTCFAll.bw"

    _cwget "https://hgdownload.soe.ucsc.edu/goldenPath/mm10/database/refGene.txt.gz" "${hub_dir}/lmm10/refGene.txt.gz"
    gzip -fkd "${hub_dir}/lmm10/refGene.txt.gz"
    _cwget "https://genome.ucsc.edu/goldenPath/help/examples/bigGenePred.as" "${hub_dir}/lmm10/bigGenePred.as"
    genePredToBigBed "lmm10" "refGene.txt"
    addBigGenePred "lmm10" "refGene.bb"
}
