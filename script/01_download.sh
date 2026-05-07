#!/bin/bash
#SBATCH --job-name=dwn_data
#SBATCH --output=%x.out
#SBATCH --error=%x.err
#SBATCH --cpus-per-task=2
#SBATCH --mem=10G

OUTPUT_DATA="$PWD/input/data"

# Define the function to download files and rewrite the CSV
process_csv() {
    local OUTPUT_FOLDER=$1
    local OLD_CSV_FILE=$2
    local NEW_CSV_FILE=$3
    local COL1=$4
    local COL2=$5
    local SUFFIX=$6

    mkdir -p "$OUTPUT_FOLDER"

    # Download the files listed in the specified columns of the CSV
    awk -F',' -v col1="$COL1" -v col2="$COL2" 'NR>1 {print $col1; print $col2}' "$OLD_CSV_FILE" | while read -r URL; do
        # Use wget to download the file into the output directory
        echo $URL
        wget -P "$OUTPUT_FOLDER" "$URL" --limit-rate=50M --no-verbose
    done

    # Rewrite the CSV file to point to the downloaded files
    awk -F',' -v col1="$COL1" -v col2="$COL2" -v output_folder="$OUTPUT_FOLDER" -v suffix="$SUFFIX" 'BEGIN {OFS = ","}
        NR==1 {print $0} 
        NR>1 {
            split($col1, a_arr, "/"); split($col2, b_arr, "/"); output = ""; # Keep only file name with extension
            st = index(a_arr[length(a_arr)], "."); st = index(b_arr[length(b_arr)], ".");
            a_ext = substr(a_arr[length(a_arr)], st+1); b_ext = substr(b_arr[length(b_arr)], st+1);
            a = substr(a_arr[length(a_arr)], 1, st-1); b = substr(b_arr[length(b_arr)], 1, st-1);
            # If suffix is not empty, add it to the file name
            if (suffix != "") {
                a = a "." suffix;
                b = b "." suffix;
            }
            # Concatenate all 
            for (i = 1; i < col1; i++) {
                output = output $i ",";
            }
            print output output_folder "/" a "." a_ext, output_folder "/" b "." b_ext;
        }' "$OLD_CSV_FILE" > "$NEW_CSV_FILE"
}

mkdir -p "input/csv/new/" "$OUTPUT_DATA/genome"

process_csv "$OUTPUT_DATA/panel_phased" "input/csv/to_download/panel_full.csv" "input/csv/new/panel_full.csv" 3 4 ""
process_csv "$OUTPUT_DATA/panel_unphased" "input/csv/to_download/panel_unphased.csv" "input/csv/new/panel_unphased.csv" 3 4 "filtered"
process_csv "$OUTPUT_DATA/HG001/truth" "input/csv/to_download/sample_sim_full_truth.csv" "input/csv/new/sample_sim_full_truth.csv" 2 3 ""
process_csv "$OUTPUT_DATA/HG001/raw" "input/csv/to_download/sample_sim_full.csv" "input/csv/new/sample_sim_full.csv" 2 3 ""

# Download the reference genome and unzip it
wget ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/GRCh38_reference_genome/GRCh38_full_analysis_set_plus_decoy_hla.fa -P $OUTPUT_DATA/genome/
wget ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/GRCh38_reference_genome/GRCh38_full_analysis_set_plus_decoy_hla.fa.fai -P $OUTPUT_DATA/genome/
