library(ggplot2)
library(dplyr)
library(tidyr)

setwd("/projects/dog/llenezet/script/benchmark/article")
source("functions.R")

# Panel simulate
path <- paste0("/projects/dog/llenezet/script/benchmark/results_impute/pipeline_info")
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
df$energy_consumption <- convert_energy(df$energy_consumption)
df$time <- convert_time(df$time) / 60

df$Process <- NA
df$Process[grepl("CHRCHECK", df$name)] <- "Initialisation"
df$Process[grepl("LISTTOFILE", df$name)] <- "Initialisation"
df$Process[grepl("BAM_IMPUTE_QUILT", df$name)] <- "Quilt"
df$Process[grepl("quilt)", df$name)] <- "Quilt"
df$Process[grepl("CONCAT_QUILT", df$name)] <- "Quilt"
df$Process[grepl("BAM_VCF_IMPUTE_GLIMPSE2", df$name)] <- "Glimpse2"
df$Process[grepl("glimpse2)", df$name)] <- "Glimpse2"
df$Process[grepl("CONCAT_GLIMPSE2", df$name)] <- "Glimpse2"
df$Process[grepl("GL_GLIMPSE1", df$name)] <- "Glimpse1"
df$Process[grepl("VCF_IMPUTE_GLIMPSE1", df$name)] <- "Glimpse1"
df$Process[grepl("glimpse1)", df$name)] <- "Glimpse1"
df$Process[grepl("CONCAT_GLIMPSE1", df$name)] <- "Glimpse1"
df$Process[grepl("MULTIQC", df$name)] <- "MultiQC"
df$Process[grepl("BCFTOOLS_STATS_TOOLS", df$name)] <- "Statistics"

df$Process <- factor(df$Process, levels = c("Initialisation", "Glimpse1", "Glimpse2", "Quilt", "Statistics", "MultiQC"), ordered = TRUE)

df$name[is.na(df$Process)]

## Divide by process
df2 <- df %>%
    group_by(Process) %>%
    summarise(
        Time = sum(time),
        CO2e = sum(CO2e),
        Energy = sum(energy_consumption),

    ) %>%
    pivot_longer(
        cols = c("CO2e", "Energy", "Time"),
        names_to = "metric", values_to = "value"
    )

breaks <- c(1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000, 100000)

png("panel_impute_process.png", width=800, height=400)
plot_benchmark(
    data_benchmark = df2, fill = "Process",
    base = 10, sigma = 1, breaks = breaks,
    x = "Process", x_label = "Process"
) +
    theme(
        legend.title = element_blank(),
    ) +
    scale_fill_npg()
dev.off()
