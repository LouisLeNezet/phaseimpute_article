#!/bin/bash

#SBATCH --job-name=testfull
#SBATCH --output=testfull.out
#SBATCH --error=testfull.err
#SBATCH --cpus-per-task=12
#SBATCH --mem=80G

source /PROGS/EXTERN/miniconda3/etc/profile.d/conda.sh
conda activate env_nf

export NXF_SINGULARITY_CACHEDIR="/home/llenezet/working_directory/singularity"
export NXF_APPTAINER_CACHEDIR="/home/llenezet/working_directory/singularity"
export SINGULARITY_CACHEDIR="/home/llenezet/working_directory/singularity"
export NXF_SINGULARITY_ENABLED=true

INPUT_FD="$PWD/input"
INPUT_DATA="$INPUT_FD/data"
INPUT_CONFIG="$INPUT_FD/config"
INPUT_CSV="$INPUT_FD/csv"
OUTDIR_PATH="$PWD/output"

MAIN_NF="/home/llenezet/working_directory/phaseimpute/main.nf"

mkdir -p $OUTDIR_PATH/results_full2
nextflow run $MAIN_NF -profile apptainer,test_full \
    -ansi-log false \
    -c $INPUT_CONFIG/benchmarking.config \
    --outdir $OUTDIR_PATH/results_full2 \
    --input $INPUT_CSV/new/sample_sim_full.csv \
    --input_region $INPUT_CSV/new/region_chr9.csv \
    -params-file $INPUT_CONFIG/test_full.yaml \
    -resume | tee pipeline_run.log