#!/bin/bash
set -euo pipefail

REF="hg38.fa"
REF_GZ="hg38.fa.gz"
SAMPLE1="ERR1469066_1.fastq.gz"
SAMPLE2="ERR1469066_2.fastq.gz"
THREADS=12

echo "========================================"
echo " Pipeline: Trim -> Align -> Sort -> BAM "
echo "           Mark Dupes -> GATK -> VCF"
echo "========================================"
echo ""

echo "========================================"

if [ -f "ERR1469066_1.fastq.gz" ] && [ -f "ERR1469066_2.fastq.gz" ]; then
    echo "Both ERR1469066_1.fastq.gz and ERR1469066_2.fastq.gz exist. Continuing script..."
else
    echo "One or both files not found. Downloading..."
    [ ! -f "ERR1469066_1.fastq.gz" ] && wget ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR146/006/ERR1469066/ERR1469066_1.fastq.gz
    [ ! -f "ERR1469066_2.fastq.gz" ] && wget ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR146/006/ERR1469066/ERR1469066_2.fastq.gz
fi

# FASTP TRIMMING
echo "=== TRIM ==="

if [ -f "TRIMMED_R1.fastq.gz" ] && [ -f "TRIMMED_R2.fastq.gz" ]; then
    echo "[skip] Trimmed files already exist"
else 
    ./fastp \
        -i "$SAMPLE1" \
        -I "$SAMPLE2" \
        -o "TRIMMED_R1.fastq.gz" \
        -O "TRIMMED_R2.fastq.gz" \
        -h fastp_report.html \
        --thread "$THREADS"
    echo "[DONE] fastp trimming"
fi

# BWA ALIGNMENT
echo "=== ALIGNMENT ==="

if [ -f "aligned.sam" ]; then
    echo "[skip] alignment already done"
else
    bwa mem -t "$THREADS" -R "@RG\tID:sample\tSM:sample\tPL:ILLUMINA\tLB:lib1" \
        "$REF" "TRIMMED_R1.fastq.gz" "TRIMMED_R2.fastq.gz" > "aligned.sam"
    echo "[DONE] alignment"
fi

echo "=== SAM TO BAM CONVERSION ==="
if [ -f "aligned.bam" ]; then
    echo "[skip] BAM file already exists"
else
    samtools view -b -o "aligned.bam" "aligned.sam"
    echo "[DONE] SAM to BAM conversion"
fi

# SAMTOOLS SORTING
echo "=== SORTING ==="

if [ -f "aligned_sorted.bam" ]; then
    echo "[skip] sorted BAM already exists"
else
    samtools sort -o "aligned_sorted.bam" "aligned.bam"
    samtools index "aligned_sorted.bam"
    echo "[DONE] sort and index"
fi

# PICARD MARK DUPLICATES
echo "=== MARK DUPLICATES ==="

if [ -f "aligned_sorted_dedup.bam" ]; then
    echo "[skip] deduplicated BAM already exists"
else
    java -jar ./picard.jar MarkDuplicates \
        I="aligned_sorted.bam" \
        O="aligned_sorted_dedup.bam" \
        M="dedup_metrics.txt"
    samtools index "aligned_sorted_dedup.bam"
    echo "[DONE] mark duplicates"
fi

# GATK VARIANT CALLING
echo "=== VARIANT CALLING ==="
if [ -f "variants.vcf.gz" ]; then
    echo "[skip] variant calling already done"
else
    gatk HaplotypeCaller \
    -R hg38.fa \
    -I aligned_sorted_dedup.bam \
    -O variants.vcf.gz \
    --native-pair-hmm-threads 12
    echo "[DONE] Variant Calling"
fi

echo ""
echo "========================================"
echo " Pipeline Complete"
echo "========================================"
echo ""
echo "Output files:"
echo "  - Trimmed: TRIMMED_R1.fastq.gz, TRIMMED_R2.fastq.gz"
echo "  - Aligned: aligned.sam, aligned.bam"
echo "  - Sorted: aligned_sorted.bam (indexed)"
echo "  - Deduplicated: aligned_sorted_dedup.bam (indexed)"
echo "  - Variants: variants.vcf.gz"
echo ""
