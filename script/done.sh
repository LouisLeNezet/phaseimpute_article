#!/bin/bash
#SBATCH --job-name=benchmark
#SBATCH --output=%x.out
#SBATCH --error=%x.err
#SBATCH --constraint=avx2
#SBATCH --cpus-per-task=12
#SBATCH --mem=80G

INPUT_FD="$PWD/input"
INPUT_DATA="$INPUT_FD/data"
INPUT_CONFIG="$INPUT_FD/config"
INPUT_CSV="$INPUT_FD/csv"

MAIN_NF="nf-core/phaseimpute -r dev"
MAIN_NF="/home/llenezet/working_directory/phaseimpute/main.nf"
OUTDIR_PATH="$PWD/output"

conda activate env_benchmark

if [ 1 -eq 1 ]; then
    echo  "Running for panelpreparation benchmarking"
    mkdir -p $OUTDIR_PATH/results_panelprep
    nextflow -log $OUTDIR_PATH/results_panelprep/phaseimpute.log run $MAIN_NF \
        -profile singularity \
        -ansi-log false \
        --outdir $OUTDIR_PATH/results_panelprep \
        -resume \
        -params-file $INPUT_CONFIG/panelprep.yaml \
        -c $INPUT_CONFIG/benchmarking.config
fi

if [ 1 -eq 1 ]; then
    echo  "Running for simulate benchmarking"
    for depth in 0.1 0.2 0.5 1 2 4 8; do
        mkdir -p $OUTDIR_PATH/results_simulate_$depth
        nextflow -log $OUTDIR_PATH/results_simulate_$depth/simulate.log run $MAIN_NF \
            -profile singularity \
            -ansi-log false \
            --outdir $OUTDIR_PATH/results_simulate_$depth \
            -resume \
            -params-file $INPUT_CONFIG/simulate.yaml \
            -c $INPUT_CONFIG/benchmarking.config \
            --depth $depth | tee pipeline_run.log
    done
    input_csv="$INPUT_CSV/new/sample_sim_depth.csv"
    echo "sample,file,index" > $input_csv

    # Concatenate all simulate data into one csv
    for depth in 0.1 0.2 0.5 1 2 4 8; do
        file="$OUTDIR_PATH/results_simulate_$depth/simulation/csv/simulate.csv"
        depth=$(echo $depth | sed 's/\.//')
        awk -F',' -v OFS=',' -v depth=$depth 'NR>1{print $1"_"depth"X",$2,$3}' $file >> $input_csv
    done
fi

if [ 1 -eq 1 ]; then
    echo  "Running for imputation benchmarking"
    mkdir -p $OUTDIR_PATH/results_impute
    nextflow -log $OUTDIR_PATH/results_impute/phaseimpute.log run $MAIN_NF \
        -profile singularity \
        -ansi-log false \
        --outdir $OUTDIR_PATH/results_impute \
        -resume \
        -params-file $INPUT_CONFIG/impute.yaml \
        -c $INPUT_CONFIG/benchmarking.config | tee pipeline_run.log
fi

if [ 1 -eq 1 ]; then
    # Prepare data for validation
    conda activate env_tools
    input_truth_depth_csv=csv/new/sample_sim_truth_depth.csv
    input_truth_csv=csv/new/sample_sim_full_truth.csv
    echo "sample,file,index" > $input_truth_depth_csv
    mkdir -p $OUTPUT_DATA/truth
    while IFS=',' read -r sample file index; do
        if [ "$sample" == "sample" ]; then
            continue
        fi
        for depth in 0.1 0.2 0.5 1 2 4 8; do
            depth_char=$(echo $depth | sed 's/\.//')
            new_file=$OUTPUT_DATA/truth/$sample"_"$depth_char"X"
            # Change sample name in the vcf file
            bcftools reheader -s <(echo $sample"_"$depth_char"X") \
                $file -o $new_file".vcf.gz"
            bcftools index  $new_file".vcf.gz"
            echo $sample"_"$depth_char"X,"$new_file".vcf.gz,"$new_file".vcf.gz.tbi" >> $input_truth_depth_csv
        done
    done < <(cat "$input_truth_csv")
fi

conda activate env_nf

if [ 1 -eq 1 ]; then
    echo  "Running for validation benchmarking"
    mkdir -p results_validate

    nextflow -log results_validate/phaseimpute.log run $MAIN_NF \
        -profile singularity \
        -ansi-log false \
        -resume \
        --outdir $OUTDIR_PATH/results_validate \
        -params-file /projects/dog/llenezet/script/benchmark/validate.yaml \
        -c /projects/dog/llenezet/script/benchmark/benchmarking.config
fi
