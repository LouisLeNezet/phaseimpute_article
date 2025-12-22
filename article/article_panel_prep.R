library(ggplot2)
library(dplyr)
library(tidyr)
library(stringr)
library(data.table)
library(ggsci)

setwd("/projects/dog/llenezet/script/benchmark")
source("article/functions.R")

path <- paste0("/projects/dog/llenezet/script/benchmark/results_panelprep/pipeline_info")
# list all files in the directory
files <- list.files(path, full.names = TRUE)
# Keep only files starting by co2footprint_trace_
files <- files[grep("co2footprint_trace_", files)]
# Keep only last generated files based on the date
files <- files[which.max(file.info(files)$ctime)]
# Read the file
df <- read.table(files, header = TRUE, row.names = 1, sep = "\t")
df <- df[-1, ] # Remove indexation of reference genome

# Convert units
df$CO2e <- convert_co2e(df$CO2e)
df$Energy <- convert_energy(df$energy_consumption)
df$Time <- convert_time(df$time) / 60

# Get the name of the process
df$Process <- NA
df$Process[grepl("CHRCHECK", df$name)] <- "Initialisation"
df$Process[grepl("PIPELINE_INITIALISATION", df$name)] <- "Initialisation"
df$Process[grepl("VCF_NORMALIZE_BCFTOOLS", df$name)] <- "Normalize"
df$Process[grepl("VCF_PHASE_SHAPEIT5", df$name)] <- "Phasing"
df$Process[grepl("VCF_CHUNK_GLIMPSE", df$name)] <- "Chunking"
df$Process[grepl("VCF_SITES_EXTRACT_BCFTOOLS", df$name)] <- "Sites extraction"
df$Process[grepl("MULTIQC", df$name)] <- "MultiQC"
df$Process <- factor(
    df$Process,
    levels = c(
        "Initialisation", "Normalize", "Phasing",
        "Chunking", "Sites extraction", "MultiQC"
    ), ordered = TRUE
)

df[is.na(df$Process), ]

df$chr <- df$name %>%
    str_extract("chr[0-9]+") %>%
    factor( levels = c(paste0("chr", c(1:22, "X", "Y")), "MultiQC"), ordered = TRUE)

df$chr[is.na(df$chr)] <- "MultiQC"

df2 <- df %>%
    group_by(chr) %>%
    summarise(
        Time = sum(Time),
        CO2e = sum(CO2e),
        Energy = sum(Energy)
    ) %>%
    pivot_longer(
        cols = c("CO2e", "Energy", "Time"),
        names_to = "metric", values_to = "value"
    )

# Plot metrics
breaks <- c(1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 10000, 100000, 1000000, 10000000)
png("article/panel_prep_chr.png", width = 800, height = 400)
plot_benchmark(
    data_benchmark = df2[df2$chr != "MultiQC", ], fill = "chr",
    base = 10, sigma = 1, breaks = breaks,
    x = "chr", x_label = "Chromosome"
) +
    theme(
        legend.title = element_blank(),
    )
dev.off()

## Divide by process
df2 <- df %>%
    group_by(Process) %>%
    summarise(
        Time = sum(Time),
        CO2e = sum(CO2e),
        Energy = sum(Energy),
    ) %>%
    pivot_longer(
        cols = c("CO2e", "Energy", "Time"),
        names_to = "metric", values_to = "value"
    )

source("article/functions.R")
options(scipen = 999, max.print = 100, tibble.width = Inf)

png("article/panel_prep_process_3axes.png", width = 800, height = 400)
plot_benchmark(
    data_benchmark = df2, fill = "Process", x = "Process",
    base = 10, sigma = 1, breaks = breaks, x_label = "Process"
) +
    theme(
        legend.title = element_blank(),
    ) +
    scale_fill_npg()
dev.off()
