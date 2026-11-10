#!/bin/sh
OUTPUT_DATA="$PWD/input/data"
mkdir -p $OUTPUT_DATA/gnomad
wget https://storage.googleapis.com/gcp-public-data--gnomad/release/3.1.1/vcf/genomes/gnomad.genomes.v3.1.1.sites.chr22.vcf.bgz \
    -P $OUTPUT_DATA/gnomad/
wget https://storage.googleapis.com/gcp-public-data--gnomad/release/3.1.1/vcf/genomes/gnomad.genomes.v3.1.1.sites.chr22.vcf.bgz.tbi \
    -P $OUTPUT_DATA/gnomad/

bcftools annotate -x INFO gnomad.genomes.v3.1.1.sites.chr22.vcf.bgz -Oz -o stripped.vcf.gz -W

bcftools annotate \
  -a gnomad.genomes.v3.1.1.sites.chr22.vcf.bgz \
  -c INFO/AC,INFO/AN,INFO/AF \
  stripped.vcf.gz -Oz -o gnomad.genomes.v3.1.1.sites_stripped.chr22.vcf.gz -W

#/projects/dog/llenezet/script/benchmark/results_impute/imputation/glimpse2/samples/HG001_1X.glimpse2.vcf.gz
#/projects/dog/llenezet/data/HG001/truth/HG001_GRCh38_1_22_v4.2.1_benchmark.vcf.gz

# ]0,0.0002], ]0.0002,0.0005], ]0.0005,0.001], ]0.001,0.002], ]0.002,0.005], ]0.005,0.01], ]0.01,0.02],
# ]0.02,0.05], ]0.05,0.1], ]0.1,0.15], ]0.15,0.2], ]0.2,0.25], ]0.25,0.3], ]0.3,0.35],
# ]0.35,0.4], ]0.4,0.45] and ]0.45,0.5]

echo -e "chr22 gnomad.genomes.v3.1.1.sites_stripped.chr22.vcf.gz HG001_1X_GRCh38_1_22_v4.2.1_benchmark.renamed.vcf.gz /projects/dog/llenezet/script/benchmark/results_impute/imputation/glimpse2/samples/HG001_1X.glimpse2.vcf.gz" \
    > concordance.lst

echo -e "chr22 results_panelprep/prep_panel/sites/1000GP_chr22_glimpse1_sites.vcf.gz HG001_1X_GRCh38_1_22_v4.2.1_benchmark.renamed.vcf.gz /projects/dog/llenezet/script/benchmark/results_impute/imputation/glimpse2/samples/HG001_1X.glimpse2.vcf.gz" \
    > concordance_2.lst

echo -e "chr22 results_panelprep/prep_panel/sites/1000GP_chr22_glimpse1_sites.vcf.gz HG001_1X_GRCh38_1_22_v4.2.1_benchmark.renamed.vcf.gz /projects/dog/llenezet/script/benchmark/results_impute/imputation/glimpse1/samples/HG001_1X.glimpse1.vcf.gz" \
    > concordance_3.lst

GLIMPSE2_concordance --input concordance.lst --output test_article_22 \
    --gt-val --af-tag AF --thread 2 --bins 0 0.01 0.05 0.1 0.2 0.5

GLIMPSE2_concordance --input concordance_2.lst --output test_article_22_2 \
    --gt-val --af-tag AF --thread 2 --bins 0 0.01 0.05 0.1 0.2 0.5
