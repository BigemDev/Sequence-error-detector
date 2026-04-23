#!/bin/bash

set -euo pipefail

REF="hg38.fa"
REF_GZ="hg38.fa.gz"

SAMPLE1="ERR1469066_1.fastq.gz"
SAMPLE2="ERR1469066_2.fastq.gz"

THREADS=12


echo "========================================"
echo " Pipeline: Trim -> Align -> Sort -> BAM "
echo "           Mark Dupes -> BQSR -> GVCF ->"
echo "           -> VCF"
echo "========================================"
echo ""
echo ""
echo ""
echo ""
echo "========================================"


if [ -f "ERR1469066_1.fastq.gz" ] && [ -f "ERR1469066_2.fastq.gz" ]; then
    echo "Both ERR1469066_1.fastq.gz and ERR1469066_2.fastq.gz exist. Continuing script..."
else
    echo "One or both files not found. Downloading..."
    [ ! -f "ERR1469066_1.fastq.gz" ] && wget ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR146/006/ERR1469066/ERR1469066_1.fastq.gz
    [ ! -f "ERR1469066_2.fastq.gz" ] && wget ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR146/006/ERR1469066/ERR1469066_2.fastq.gz
fi


echo "=== TRIM ==="

#fastp trimming
if [ -f "${REF}.fq"]; then

    echo "[skip] $REF.bwt"

else 
    ./fastp \
    -i "$SAMPLE1" \
    -I "$SAMPLE2" \
    -o "TRIMMED_R1.fastq.gz" \
    -O "TRIMMED_R2.fastq.gz" \
    -h fastp_raport.html
fi

# trimmed_R1 trimmed_R2.fastq.gz
#-R "@RG\tID:sample\tSM:sample\tPL:ILLUMINA\tLB:lib1"

#bwa mem alignment
if [ -f "${REF}.fq" ]; then
    echo "[skip] $REF.fq"

else
    bwa mem -t 2 -R "@RG\tID:sample\tSM:sample\tPL:ILLUMINA\tLB:lib1" "$REF" "TRIMMED_R1.fastq.gz" "TRIMMED_R2.fastq.gz" > "${REF}.sam"
    echo "[DONE] alignment"
fi


#samtools sorting bam
if [ -f "${REF.sam}" ]; then
    echo "[skip] $REF_sorted.bam"

else
    samtools sort -o "${REF}_sorted.bam" "${REF}.bam"
    samtools index "${REF}.bam"
    echo "[DONE] sort"
fi

#picard mark duplicates
if [ -f "${REF}.bam"]; then

    echo "[skip] $REF.bam"

else

    java -jar ./picard.jar MarkDuplicates \
    I="${REF}_sorted.bam" \ 
    O="${REF}_Dup.bam" \ 
    M="${REF}_Dup.metrics.txt"

    samtools index "${REF}_Dup.bam"
fi



#variant calling
if [ -f "${REF}.bam" ]; then
    echo "[skip] variant calling"

else
    gatk HaplotypeCaller \                       
        -R hg38.fa \ 
        -I "${REF}_Dup.bam"\
        -O "${REF}_gatk_variants.vcf.gz"

    echo "[DONE] Variant Calling"
fi

#dodac filtracje wariantow