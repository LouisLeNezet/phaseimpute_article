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

INPUT_FD="$PWD/input"
INPUT_DATA="$INPUT_FD/data"
INPUT_CONFIG="$INPUT_FD/config"
INPUT_CSV="$INPUT_FD/csv"

MAIN_NF="nf-core/phaseimpute -r dev"
MAIN_NF="/home/llenezet/working_directory/phaseimpute/main.nf"
OUTDIR_PATH="$PWD/output"

CSV_FULL_PANEL="$INPUT_CSV/new/panel_unphased_filtered.csv"
CSV_HALF_PANEL="$INPUT_CSV/new/panel_unphased_filtered_half.csv"

if [ 1 -eq 1 ]; then
    rm -f $CSV_FULL_PANEL
    rm -f $CSV_HALF_PANEL
    echo "panel,chr,vcf,index" > $CSV_FULL_PANEL
    echo "panel,chr,vcf,index" > $CSV_HALF_PANEL
    conda activate env_tools
    # Select in the unphased panel only the snp present in the phased one
    for chr in 1 22; do
        PHASED_PANEL=$INPUT_DATA/panel_phased/CCDG_14151_B01_GRM_WGS_2020-08-05_chr$chr.filtered.shapeit2-duohmm-phased.vcf.gz
        UNPHASED_PANEL=$INPUT_DATA/panel_unphased/20201028_CCDG_14151_B01_GRM_WGS_2020-08-05_chr$chr.recalibrated_variants.vcf.gz
        NEW_UNPHASED_PANEL=$INPUT_DATA/panel_unphased/20201028_CCDG_14151_B01_GRM_WGS_2020-08-05_chr$chr.filtered.recalibrated_variants.vcf.gz
        NEW_UNPHASED_HALF_PANEL=$INPUT_DATA/panel_unphased/20201028_CCDG_14151_B01_GRM_WGS_2020-08-05_chr$chr.filtered.recalibrated_variants.half.vcf.gz
        PHASED_PANEL_SITES=$INPUT_DATA/panel_unphased/CCDG_14151_B01_GRM_WGS_2020-08-05_chr$chr.sites

        if [ 1 -eq 1 ]; then
            echo "Filter the unphased panel"
            bcftools isec -n=2 -w2 -Oz \
                $PHASED_PANEL $UNPHASED_PANEL | \
                bcftools annotate \
                    -x FORMAT,^FORMAT/GT \
                    --threads 4 \
                    --write-index=csi \
                    -Oz -o $NEW_UNPHASED_PANEL
        fi

        echo "1000GP,chr$chr,$NEW_UNPHASED_PANEL,$NEW_UNPHASED_PANEL.csi" >> $CSV_FULL_PANEL

        if [ 1 -eq 1 ]; then
            echo "Split the unphased panel in half"
            # Extract the samples names
            bcftools query -l $NEW_UNPHASED_PANEL > $NEW_UNPHASED_PANEL.samples
            # Select half of it
            head -n $(($(wc -l $NEW_UNPHASED_PANEL.samples | cut -f1 -d' ') / 2)) \
                $NEW_UNPHASED_PANEL.samples > $NEW_UNPHASED_PANEL.samples.half
            bcftools view \
                -S $NEW_UNPHASED_PANEL.samples.half \
                -Oz -o $NEW_UNPHASED_HALF_PANEL $NEW_UNPHASED_PANEL \
                --threads 4 --write-index=csi
        fi
        echo "1000GP_half,chr$chr,$NEW_UNPHASED_HALF_PANEL,$NEW_UNPHASED_HALF_PANEL.csi" >> $CSV_HALF_PANEL
    done
fi

if [ 2 -eq 1 ]; then
    conda activate env_nf

    echo  "Running for phasing benchmarking"
    mkdir -p $OUTDIR_PATH/results_phasing

    nextflow -log $OUTDIR_PATH/results_phasing/phaseimpute.log run $MAIN_NF \
        -profile singularity \
        -ansi-log false \
        --outdir $OUTDIR_PATH/results_phasing \
        -resume \
        -params-file $INPUT_CONFIG/panelphasing.yaml \
        -c $INPUT_CONFIG/benchmarking.config | tee pipeline_run.log
fi


if [ 1 -eq 1 ]; then
    conda activate env_nf

    echo  "Running for phasing_half benchmarking"
    mkdir -p $OUTDIR_PATH/results_phasing_half

    nextflow -log $OUTDIR_PATH/results_phasing_half/phaseimpute.log run $MAIN_NF \
        -profile singularity \
        -ansi-log false \
        --outdir $OUTDIR_PATH/results_phasing_half \
        -resume \
        -params-file $INPUT_CONFIG/panelphasing_half.yaml \
        -c $INPUT_CONFIG/benchmarking.config | tee pipeline_run.log
fi