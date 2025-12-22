#!/bin/bash

#SBATCH --job-name=testfull
#SBATCH --output=testfull.out
#SBATCH --error=testfull.err
#SBATCH --constraint=avx2
#SBATCH --cpus-per-task=24
#SBATCH --mem=50G

. /local/env/envconda.sh
conda activate env_nf

nextflow run ../phaseimpute/main.nf -profile singularity,test_full \
    -ansi-log false \
    -c phaseimpute.config \
    --outdir results_direct \
    --input sample_sim_full.csv \
    --input_region regions_full.csv\
    -resume