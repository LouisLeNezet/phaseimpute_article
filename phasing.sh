#!/bin/bash
#SBATCH --job-name=phasing
#SBATCH --output=%x.out
#SBATCH --error=%x.err
#SBATCH --constraint=avx2
#SBATCH --cpus-per-task=12
#SBATCH --mem=80G
#SBATCH --exclude=cl1n[015-016,018-023,030,033-039,041-043,045-046,050],ecogeno[01-04],genogpu[1-2]


#--nodelist=cl1n031,cl1n032,cl1n048,cl1n049,cl1n052,cl1n053,cl1n054,cl1n055,cl1n056,cl1n059,cl1n058
# Need to run on Intel(R) Xeon(R) CPU E5-2670 v3 @ 2.30GHz
# cl1n031 cl1n032 cl1n048 cl1n049 cl1n052 cl1n053 cl1n054 cl1n055 cl1n056 cl1n059 cl1n058

. /local/env/envconda.sh

OUTPUT_DATA=$1
OUTPUT_DATA="/projects/dog/llenezet/data"
MAIN_NF="nf-core/phaseimpute -r 1.0.0"
MAIN_NF="/projects/dog/llenezet/script/phaseimpute/main.nf"
OUTDIR_PATH="/projects/dog/llenezet/script/benchmark"

if [ 1 -eq 1 ]; then
    rm -f csv/new/panel_unphased.csv
    rm -f csv/new/panel_unphased_half.csv
    echo "panel,chr,vcf,index" > csv/new/panel_unphased.csv
    echo "panel,chr,vcf,index" > csv/new/panel_unphased_half.csv
    conda activate env_tools
    # Select in the unphased panel only the snp present in the phased one
    for chr in 1 22; do
        PHASED_PANEL=$OUTPUT_DATA/panel_phased/CCDG_14151_B01_GRM_WGS_2020-08-05_chr$chr.filtered.shapeit2-duohmm-phased.vcf.gz
        UNPHASED_PANEL=$OUTPUT_DATA/panel_unphased/20201028_CCDG_14151_B01_GRM_WGS_2020-08-05_chr$chr.recalibrated_variants.vcf.gz
        NEW_UNPHASED_PANEL=$OUTPUT_DATA/panel_unphased/20201028_CCDG_14151_B01_GRM_WGS_2020-08-05_chr$chr.filtered.recalibrated_variants.vcf.gz
        NEW_UNPHASED_HALF_PANEL=$OUTPUT_DATA/panel_unphased/20201028_CCDG_14151_B01_GRM_WGS_2020-08-05_chr$chr.filtered.recalibrated_variants.half.vcf.gz
        PHASED_PANEL_SITES=$OUTPUT_DATA/panel_unphased/CCDG_14151_B01_GRM_WGS_2020-08-05_chr$chr.sites
        if [ 2 -eq 1 ]; then
            echo "Querying the phased panel"
            bcftools query -f '%CHROM\t%POS\t%REF\t%ALT\n' -o $PHASED_PANEL_SITES $PHASED_PANEL
            echo -e "##fileformat=VCFv4.2\n#CHROM\tPOS\tID\tREF\tALT" > minimal_header.vcf
            cat minimal_header.vcf $PHASED_PANEL_SITES > $PHASED_PANEL_SITES.vcf
        fi

        if [ 2 -eq 1 ]; then
            echo "Filter the unphased panel"
            bcftools annotate \
                -x FORMAT,^FORMAT/GT \
                --regions-file $PHASED_PANEL_SITES.vcf \
                --threads 4 \
                --write-index=csi \
                -Oz -o $NEW_UNPHASED_PANEL \
                $UNPHASED_PANEL
        fi

        echo "1000GP,chr$chr,$NEW_UNPHASED_PANEL,$NEW_UNPHASED_PANEL.csi" >> csv/new/panel_unphased.csv

        if [ 2 -eq 1 ]; then
            echo "Split the unphased panel in half"
            # Extract the samples names
            bcftools query -l $NEW_UNPHASED_PANEL > $NEW_UNPHASED_PANEL.samples
            # Select half of it
            head -n $(($(wc -l $NEW_UNPHASED_PANEL.samples | cut -f1 -d' ') / 2)) $NEW_UNPHASED_PANEL.samples > $NEW_UNPHASED_PANEL.samples.half
            bcftools view \
                -S $NEW_UNPHASED_PANEL.samples.half \
                -Oz -o $NEW_UNPHASED_HALF_PANEL $NEW_UNPHASED_PANEL \
                --threads 4 --write-index=csi
        fi
        echo "1000GP_half,chr$chr,$NEW_UNPHASED_HALF_PANEL,$NEW_UNPHASED_HALF_PANEL.csi" >> csv/new/panel_unphased_half.csv
    done
fi

if [ 2 -eq 1 ]; then
    conda activate env_nf

    echo  "Running for phasing benchmarking"
    mkdir -p results_phasing

    nextflow -log results_phasing/phaseimpute.log run $MAIN_NF \
        -profile singularity \
        -ansi-log false \
        --outdir results_phasing \
        -resume \
        -params-file $OUTDIR_PATH/panelphasing.yaml \
        -c $OUTDIR_PATH/benchmarking.config
fi


if [ 1 -eq 1 ]; then
    conda activate env_nf

    echo  "Running for phasing_half benchmarking"
    mkdir -p results_phasing_half

    nextflow -log results_phasing_half/phaseimpute.log run $MAIN_NF \
        -profile singularity \
        -ansi-log false \
        --outdir results_phasing_half \
        -resume \
        -params-file $OUTDIR_PATH/panelphasing_half.yaml \
        -c $OUTDIR_PATH/benchmarking.config
fi