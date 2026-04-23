#!/bin/bash

set -euo pipefail

REF="hg38.fa"
REF_GZ="hg38.fa.gz"


if [ -f "hg38.fa.gz" ]; then
    echo "hg38.fa.gz exists"
else
    echo "hg38.fa.gz not found. Downloading..."
    wget https://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz
fi

echo "=== Reference ==="

#decompress
if [ -f "$REF" ]; then
    echo "[skip] $REF"
elif [ -f "$REF_GZ" ]; then
    echo "[decomp] $REF_GZ"
    gunzip "$REF_GZ"
    echo "[comp]"
else
    echo "no files"
    exit 1
fi


# faidx .fa -> hg38.fa.fai
# picard CreateSeqDic -R hg38.fa -O hg38.dict
# bwa index

#samtools faidx
if [ -f "${REF}.fai" ]; then
    echo "[skip] $REF.fai"

else
    echo "[exec samtools faidx]"
    samtools faidx "$REF"
fi


#picard dict
DICT="${REF%.fa}.dict"
if [ -f "$DICT" ]; then
    echo "[SKIP] dict exist"
else 
    echo "[RUN] picard"
    java -jar ./picard.jar CreateSequenceDictionary R="$REF" O="$DICT"
    echo "[DONE] Sequence dictionary"
fi


# Bwa Index
if [ -f "${REF}.bwt" ]; then
    echo "[skip] $REF.bwt"
    
else
    echo "[RUN]"
    bwa index "$REF"
fi

echo " === FINISHED === "