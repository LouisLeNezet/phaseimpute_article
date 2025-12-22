#!/bin/bash
#SBATCH --job-name=benchmark
#SBATCH --output=%x.out
#SBATCH --error=%x.err
#SBATCH --constraint=avx2
#SBATCH --cpus-per-task=12
#SBATCH --mem=80G

. /local/env/envconda.sh

OUTPUT_DATA=$1
OUTPUT_DATA="/projects/dog/llenezet/data"
MAIN_NF="nf-core/phaseimpute -r 1.0.0"
MAIN_NF="/projects/dog/llenezet/script/phaseimpute/main.nf"
OUTDIR_PATH="/projects/dog/llenezet/script/benchmark"

conda activate env_nf

if [ 1 -eq 1 ]; then
    echo  "Running for panelpreparation benchmarking"
    mkdir -p results_panelprep
    nextflow -log results_panelprep/phaseimpute.log run $MAIN_NF \
        -profile singularity \
        -ansi-log false \
        --outdir $OUTDIR_PATH/results_panelprep \
        -resume \
        -params-file /projects/dog/llenezet/script/benchmark/panelprep.yaml \
        -c /projects/dog/llenezet/script/benchmark/benchmarking.config
fi

if [ 1 -eq 1 ]; then
    echo  "Running for simulate benchmarking"
    for depth in 0.1 0.2 0.5 1 2 4 8; do
        mkdir -p results_simulate_$depth
        nextflow -log results_simulate_$depth/simulate.log run $MAIN_NF \
            -profile singularity \
            -ansi-log false \
            --outdir $OUTDIR_PATH/results_simulate_$depth \
            -resume \
            -params-file /projects/dog/llenezet/script/benchmark/simulate.yaml \
            -c /projects/dog/llenezet/script/benchmark/benchmarking.config \
            --depth $depth
    done
    input_csv=csv/new/sample_sim_depth.csv
    echo "sample,file,index" > $input_csv

    # Concatenate all simulate data into one csv
    for depth in 0.1 0.2 0.5 1 2 4 8; do
        file="results_simulate_$depth/simulation/csv/simulate.csv"
        depth=$(echo $depth | sed 's/\.//')
        awk -F',' -v OFS=',' -v depth=$depth 'NR>1{print $1"_"depth"X",$2,$3}' $file >> $input_csv
    done
fi

if [ 1 -eq 1 ]; then
    echo  "Running for imputation benchmarking"
    mkdir -p results_impute
    nextflow -log results_impute/phaseimpute.log run $MAIN_NF \
        -profile singularity \
        -ansi-log false \
        --outdir $OUTDIR_PATH/results_impute \
        -resume \
        -params-file /projects/dog/llenezet/script/benchmark/impute.yaml \
        -c /projects/dog/llenezet/script/benchmark/benchmarking.config
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
