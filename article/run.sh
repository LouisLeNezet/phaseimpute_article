#!/bin/bash
#SBATCH --job-name=article
#SBATCH --output=%x.out
#SBATCH --error=%x.err
#SBATCH --constraint=avx2
#SBATCH --cpus-per-task=2
#SBATCH --mem=80G

. /local/env/envconda.sh
conda activate env_benchmark

if [ 2 -eq 1 ]; then
    # Extract genotypes from VCF
    VCF_IN=/projects/dog/llenezet/data/panel_phased/CCDG_14151_B01_GRM_WGS_2020-08-05_chr21.filtered.shapeit2-duohmm-phased.vcf.gz
    VCF_OUT=/projects/dog/llenezet/script/benchmark/article/test_vcf/1000GP_chr21_ref

    bcftools view -h $VCF_IN | tail -1 | \
        sed '1s/#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT/CHROM\tPOS\tREF\tALT/' \
        > $VCF_OUT.header.txt

    bcftools query \
        -f '%CHROM\t%POS\t%REF\t%ALT[\t%GT]\n' \
        -i 'COUNT(GT="het")>100' \
        $VCF_IN > $VCF_OUT.genotypes.noheader.tsv
    cat $VCF_OUT.header.txt $VCF_OUT.genotypes.noheader.tsv > $VCF_OUT.genotypes.tsv
    head -n 1000 $VCF_OUT.genotypes.tsv > $VCF_OUT.genotypes.1000.tsv
    rm $VCF_OUT.genotypes.noheader.tsv

    wc -l $VCF_OUT.genotypes.tsv

    VCF_IN=/projects/dog/llenezet/script/benchmark/results_phasing/prep_panel/panel/1000GP_chr21_phased.vcf.gz
    VCF_OUT=/projects/dog/llenezet/script/benchmark/article/test_vcf/1000GP_chr21_phased

    bcftools view -h $VCF_IN | tail -1 | \
        sed '1s/#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT/CHROM\tPOS\tREF\tALT/' \
        > $VCF_OUT.header.txt

    bcftools query \
        -f '%CHROM\t%POS\t%REF\t%ALT[\t%GT]\n' \
        -i 'COUNT(GT="het")>100' \
        $VCF_IN > $VCF_OUT.genotypes.noheader.tsv
    cat $VCF_OUT.header.txt $VCF_OUT.genotypes.noheader.tsv > $VCF_OUT.genotypes.tsv
    head -n 1000 $VCF_OUT.genotypes.tsv > $VCF_OUT.genotypes.1000.tsv
    rm $VCF_OUT.genotypes.noheader.tsv

    wc -l $VCF_OUT.genotypes.tsv

    VCF_IN=/projects/dog/llenezet/script/benchmark/results_phasing_half/prep_panel/panel/1000GP_half_chr22_phased.vcf.gz
    VCF_OUT=/projects/dog/llenezet/script/benchmark/article/test_vcf/1000GP_half_chr22_phased

    bcftools view -h $VCF_IN | tail -1 | \
        sed '1s/#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT/CHROM\tPOS\tREF\tALT/' \
        > $VCF_OUT.header.txt

    bcftools query \
        -f '%CHROM\t%POS\t%REF\t%ALT[\t%GT]\n' \
        -i 'COUNT(GT="het")>100' \
        $VCF_IN > $VCF_OUT.genotypes.noheader.tsv
    cat $VCF_OUT.header.txt $VCF_OUT.genotypes.noheader.tsv > $VCF_OUT.genotypes.tsv
    head -n 1000 $VCF_OUT.genotypes.tsv > $VCF_OUT.genotypes.1000.tsv
    rm $VCF_OUT.genotypes.noheader.tsv

    wc -l $VCF_OUT.genotypes.tsv
fi

if [ 1 -eq 1 ]; then
    # Loop over chromosomes
    if [ 1 -eq 1 ]; then
        for PANEL in "_half"; do
            mkdir -p article/phasing${PANEL}
            for CHROM in 1 22 ; do
                # Compare genotype result with before after phasing
                VCF_PHASED_REF="/projects/dog/llenezet/data/panel_phased/CCDG_14151_B01_GRM_WGS_2020-08-05_chr${CHROM}.filtered.shapeit2-duohmm-phased.vcf.gz"
                VCF_PHASED="/projects/dog/llenezet/script/benchmark/results_phasing${PANEL}/prep_panel/panel/1000GP${PANEL}_chr${CHROM}_phased.vcf.gz"

                # Extract samples
                bcftools query -l $VCF_PHASED_REF | head -10 > /projects/dog/llenezet/script/benchmark/article/test_vcf/1000GP${PANEL}_chr${CHROM}_phased.10samples.txt

                # Loop over samples
                for SAMPLE in $(cat /projects/dog/llenezet/script/benchmark/article/test_vcf/1000GP${PANEL}_chr${CHROM}_phased.10samples.txt); do
                    echo $SAMPLE
                    # Extract vcf for each sample
                    OUTPUT_VCF_REF="/projects/dog/llenezet/script/benchmark/article/test_vcf/sample_phased_ref.vcf.gz"
                    OUTPUT_VCF="/projects/dog/llenezet/script/benchmark/article/test_vcf/sample_phased.vcf.gz"
                    bcftools view -s $SAMPLE $VCF_PHASED_REF -o $OUTPUT_VCF_REF --write-index csi --regions chr$CHROM
                    bcftools view -s $SAMPLE $VCF_PHASED -o $OUTPUT_VCF --write-index csi --regions chr$CHROM
                    whatshap compare --sample $SAMPLE \
                        --names truth,phased \
                        --tsv-pairwise article/phasing${PANEL}/eval_chr${CHROM}_${SAMPLE}.tsv \
                        $OUTPUT_VCF_REF $OUTPUT_VCF
                done
            done
        done
    fi

    # Concatenate all the tsv files
    echo "Concatenate all the tsv files"
    OUTPUT_TSV=/projects/dog/llenezet/script/benchmark/article/phasing/eval_allchr.tsv
    # Add header to output tsv
    head -1 article/phasing/eval_chr${CHROM}_${SAMPLE}.tsv > $OUTPUT_TSV
    for PANEL in "" "_half"; do
        for CHROM in 1 22 ; do
            for SAMPLE in $(cat /projects/dog/llenezet/script/benchmark/article/test_vcf/1000GP${PANEL}_chr${CHROM}_phased.10samples.txt); do
                echo $SAMPLE
                # Extract vcf for each sample
                TSV=article/phasing${PANEL}/eval_chr${CHROM}_${SAMPLE}.tsv
                tail -1 $TSV >> $OUTPUT_TSV
            done
        done
    done
fi

if [ 2 -eq 1 ]; then
    conda activate env_r
    Rscript /projects/dog/llenezet/script/benchmark/article/test.R
fi