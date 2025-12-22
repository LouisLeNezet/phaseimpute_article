# Benchmarking of [`nf-core/phaseimpute`](https://nf-co.re/phaseimpute)

This repository is meant to store the benchmarking procedure of the nf-core/phaseimpute pipeline.
You'll find here all the different scripts and files necessary to reproduce our results.

:warning: Disclaimer: the computational resources used highly depends on the infrastructure this
benchmarking is launched on.

## Organisation

This repository is organised as follow:

- input: Folder with all the data necessary to run the benchmark
    - csv: Folden with all the samplesheet listing the different files
    - data: Folder with the raw input data
    - config: Folder with configuration files (`.config` and `.yaml`) used for the differents steps
- output: Folder where the results for each benchmarking step will be stored
- scripts: Folder with all scripts ran
- environment:
    - `env_benchmark.yml`: conda environment used to realise the benchmark
    - `env_aws_download.yml`: conda environment used to download the data

## Preparation

The first step is to gather all the data needeed for the benchmarking.
To do so please run the following

```bash
mamba env create -f environment/env_aws_download.yml
sbatch script/01_download.sh
```

## Benchmarking

The benchmarking presented here aims to evaluate the computational performance of nf-core/phaseimpute
as well as checking the accuracy of the outputs obtained.

