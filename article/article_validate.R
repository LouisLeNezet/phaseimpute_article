library(ggplot2)
library(dplyr)
library(tidyr)
library(stringr)
library(ggsci)

setwd("/projects/dog/llenezet/script/benchmark")
source("functions.R")

# Panel simulate
path <- paste0("/projects/dog/llenezet/script/benchmark/results_validate/pipeline_info")
# list all files in the directory
files <- list.files(path, full.names = TRUE)
# Keep only files starting by co2footprint_trace_
files <- files[grep("co2footprint_trace_", files)]
# Keep only last generated files based on the date
files <- files[which.max(file.info(files)$ctime)]
# Read the file
df <- read.table(files, header = TRUE, row.names = 1, sep = "\t")

# Convert units
df$CO2e <- convert_co2e(df$CO2e)
df$energy_consumption <- convert_energy(df$energy_consumption)
df$time <- convert_time(df$time) / 60

df$Process <- NA
df$Process[grepl("CHRCHECK", df$name)] <- "Initialisation"
df$Process[grepl("CONCAT_PANEL", df$name)] <- "Truth & panel\npreparation"
df$Process[grepl("_TRUTH", df$name)] <- "Truth & panel\npreparation"
df$Process[grepl("VCF_CONCORDANCE_GLIMPSE2", df$name)] <- "Concordance"
df$Process[grepl("BCFTOOLS_STATS", df$name)] <- "Statistics"
df$Process[grepl("MULTIQC", df$name)] <- "MultiQC"

df$Process <- factor(df$Process, levels = c("Initialisation", "Truth & panel\npreparation", "Concordance", "Statistics", "MultiQC"), ordered = TRUE)

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

png("article/panel_validate_process.png", width=800, height=400)
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

path <- paste0("/projects/dog/llenezet/script/benchmark/results_validate/validation/stats/AllSamples.txt")
df <- read.table(path, header = TRUE, sep = " ")
df$Depth <- str_split_i(df$ID, "_", 2) |>
    str_replace("X", "") |>
    str_replace("0", "0.") |>
    as.numeric()
summary(df)

df <- df %>%
    filter(Tools != "glimpse1")

library(scales)
revlog100_trans <- trans_new(
  name = "revlog100",
  transform = function(x) -log10(101 - x),
  inverse = function(x) 101 - 10^(-x),
  domain = c(0, 100)
)

png("article/panel_validate_concordance.png", width=800, height=600)
ggplot(df |> filter(Depth != "8"), aes(x = mean_AF * 100, y = best_gt_rsquared * 100, color = Tools)) +
    geom_line() +
    geom_point() +
    theme_minimal(base_size = 15) +
    theme(
        plot.title = element_text(size = 20, hjust = 0.5)
    ) +
    facet_wrap(~ Depth) +
    scale_x_continuous(
        trans = "pseudo_log",
        breaks = c(0, 1, 2, 5, 10, 20, 40),
        limits = c(0, 40)
    ) +
    scale_y_continuous(
        trans = revlog100_trans,
        breaks = c(20, 60, 80, 90, 95, 98, 99, 100),
        limits = c(20, 100)
    ) +
    scale_color_npg() +
    labs (
        x = "Mean AF (%)",
        y = "Best GT R² (%)",
        title = "Concordance by\nGenomic depth simulated",
        color = "Tools"
    )
dev.off()

png("article/panel_validate_concordance_tools.png", width=800, height=400)
ggplot(df, aes(x = mean_AF * 100, y = best_gt_rsquared * 100, color = as.factor(Depth))) +
    geom_line() +
    geom_point() +
    theme_minimal(base_size = 15) +
    theme(
        plot.title = element_text(size = 20, hjust = 0.5)
    ) +
    facet_wrap(~ Tools) +
    scale_x_continuous(
        trans = "pseudo_log",
        breaks = c(0, 1, 2, 5, 10, 20, 40),
        limits = c(0, 40)
    ) +
    scale_y_continuous(
        trans = revlog100_trans,
        breaks = c(20, 50, 70, 80, 90, 95, 98, 99, 100),
        limits = c(20, 100)
    ) +
    labs (
        x = "Mean AF (%)",
        y = "Best GT R² (%)",
        title = "Concordance between tools",
        color = "Genomic depth\nsimulated"
    )
dev.off()
