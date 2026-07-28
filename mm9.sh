mm9() {
    _cwget "https://hgdownload.gi.ucsc.edu/goldenPath/mm9/bigZips/mm9.chrom.sizes" "${hub_dir}/lmm9/lmm9.chrom.sizes"
    _cwget "https://hgdownload.gi.ucsc.edu/goldenPath/mm9/bigZips/mm9.2bit" "${hub_dir}/lmm9/lmm9.2bit"
    genomes "lmm9" "Mus Musculus (mm9)" "chr18:36900000-37900000"

    > "${hub_dir}/lmm9/trackDb.txt"

    _ccp "/home/ljw/sdc1/cpcdh/ESC.CTCF.merged.sort.bam_RPKM.bw" "${hub_dir}/lmm9/ESC.CTCF.merged.sort.bam_RPKM.bw"
    addBigWig "lmm9" "ESC.CTCF.merged.sort.bam_RPKM.bw"

    _cwget "https://hgdownload.soe.ucsc.edu/goldenPath/mm9/database/refGene.txt.gz" "${hub_dir}/lmm9/refGene.txt.gz"
    gzip -fkd "${hub_dir}/lmm9/refGene.txt.gz"
    _cwget "https://genome.ucsc.edu/goldenPath/help/examples/bigGenePred.as" "${hub_dir}/lmm9/bigGenePred.as"
    genePredToBigBed "lmm9" "refGene.txt"
    addBigGenePred "lmm9" "refGene.bb"
}
