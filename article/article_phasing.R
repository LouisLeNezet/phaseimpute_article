library(ggplot2)
library(dplyr)
library(tidyr)
library(stringr)
library(data.table)
library(ggsci)

setwd("/projects/dog/llenezet/script/benchmark")
source("article/functions.R")

options(scipen = 999, max.print = 100, tibble.width = Inf)

# Panel phasing
all_df <- list()
for (i in c("full", "half")) {
    path <- paste0("/projects/dog/llenezet/script/benchmark/results_phasing_", i, "/pipeline_info")
    # list all files in the directory
    files <- list.files(path, full.names = TRUE)
    # Keep only files starting by co2footprint_trace_
    files <- files[grep("co2footprint_trace_", files)]
    # Keep only last generated files based on the date
    files <- files[which.max(file.info(files)$ctime)]
    # Read the file
    all_df[[as.character(i)]] <- read.table(files, header = TRUE, row.names = 1, sep = "\t")
    all_df[[as.character(i)]] <- all_df[[as.character(i)]][-1, ] # Remove indexation of reference genome
}

df <- data.table::rbindlist(all_df, idcol = "panel")

# Convert units
df$CO2e <- convert_co2e(df$CO2e)
df$energy_consumption <- convert_energy(df$energy_consumption)
df$time <- convert_time(df$time) / 60

df$Process <- NA
df$Process[grepl("CHRCHECK_PANEL", df$name)] <- "Initialisation"
df$Process[grepl("VCF_PHASE_SHAPEIT5", df$name)] <- "Phasing"
df$Process[grepl("VCF_CHUNK_GLIMPSE", df$name)] <- "Chunking"
df$Process[grepl("VCF_SITES_EXTRACT_BCFTOOLS", df$name)] <- "Sites extraction"
df$Process[grepl("MULTIQC", df$name)] <- "MultiQC"
df$Process <- factor(df$Process, levels = c("Initialisation", "Phasing", "Chunking", "Sites extraction", "MultiQC"), ordered = TRUE)

df$chr <- NA
df$chr <- str_extract(df$name, "chr(1|22)")
df$chr[grepl("MULTIQC", df$name)] <- "MultiQC"

df$name[is.na(df$Process)]
df$panel <- factor(df$panel, levels = c("full", "half"), ordered = TRUE)

## Divide by process
df2 <- df %>%
    dplyr::mutate(chr = str_replace_all(chr, "chr", "Chromosome ")) %>%
    dplyr::group_by(Process, chr, panel) %>%
    dplyr::summarise(
        Time = sum(time),
        CO2e = sum(CO2e),
        Energy = sum(energy_consumption),

    ) %>%
    tidyr::pivot_longer(
        cols = c("CO2e", "Energy", "Time"),
        names_to = "metric", values_to = "value"
    )

df2$condition <- paste0(df2$chr, " - ", df2$panel, " panel")

breaks <- c(1, 10, 100, 1000, 10000, 100000)

png("article/panel_phasing_process_3axes.png", width = 800, height = 400)
plot_benchmark(
    data_benchmark = df2, fill = "condition",
    base = 10, sigma = 1, breaks = breaks
) +
    theme(
        legend.title = element_blank(),
    ) +
    scale_fill_npg()
dev.off()

# Get Whatshap metrics
path <- paste0("/projects/dog/llenezet/script/benchmark/article/phasing")
# list all files in the directory
files <- list.files(path, full.names = TRUE)

all_df <- list()
for (file in files) {
    all_df[[file]] <- read.table(file, header = TRUE, sep = "\t", comment.char = "") |>
        dplyr::mutate(panel = "full") |>
        dplyr::rename(sample = X.sample)
}
path <- paste0("/projects/dog/llenezet/script/benchmark/article/phasing_half")
# list all files in the directory
files <- list.files(path, full.names = TRUE)

for (file in files) {
    all_df[[file]] <- read.table(file, header = TRUE, sep = "\t", comment.char = "") |>
        dplyr::mutate(panel = "half") |>
        dplyr::rename(sample = X.sample)
}

hap_df <- data.table::rbindlist(all_df, idcol = "file") |>
    select(c(
        "chromosome", "sample", "all_switch_rate", "panel",
        "all_switchflip_rate", "blockwise_hamming_rate"
    ))

hap_df %>%
    group_by(panel, chromosome) |>
    summarise(
        mean_switch = mean(all_switch_rate, na.rm = TRUE),
        sd_switch = sd(all_switch_rate, na.rm = TRUE),
        mean_switch_flip = mean(all_switchflip_rate, na.rm = TRUE),
        sd_switch_flip = sd(all_switchflip_rate, na.rm = TRUE),
        mean_hamming = mean(blockwise_hamming_rate, na.rm = TRUE),
        sd_hamming = sd(blockwise_hamming_rate, na.rm = TRUE)
    )

hap_df_wide <- hap_df |>
    rename(
        "Switch error rate"= all_switch_rate,
        "Switch and flip error rate" = all_switchflip_rate,
        "Hamming distance rate" = blockwise_hamming_rate
    ) |>
    pivot_longer(
        cols = !c("chromosome", "sample", "panel")
    )
hap_df_wide$group <- interaction(hap_df_wide$panel, hap_df_wide$chromosome, sep = "_")
labels <- c("Full", "Half", "Full", "Half")

library(legendry)
library(grid)
library(gridExtra)

m <- 5

p <- ggplot(hap_df_wide, aes(x = group, y = value * 100, fill = chromosome)) +
    geom_boxplot() +
    facet_wrap(~ name, scales = "free_y") +
    labs(
        x = NULL,
        y = "Rate in %",
        title = "Phasing accuracy",
        fill = "Chromosomes"
    ) +
    theme_minimal() +
    theme(
        text = element_text(size = 15),
        axis.text.x = element_text(angle = 0, hjust = 0.5, margin = margin(t = m, b = m)),
        axis.text.y = element_text(margin = margin(l = m, r = m)),
        axis.title.x = element_text(margin = margin(t = m, b = m)),
        axis.title.y = element_text(size = 14, face = "bold", margin = margin(l = m, r = m)),
        axis.ticks.length = unit(15, "pt"),
        plot.title = element_text(margin = margin(t = m, b = m), hjust = 0.5),
        strip.text = element_text(face = "bold", size = 12),
        legend.position = "none",
    ) +
    scale_x_discrete(guide = "axis_nested") +
    scale_y_continuous(
        trans = scales::pseudo_log_trans(),
        breaks = c(0, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 5, 10, 20, 30, 38, 40, 42, 44, 46, 48, 50, 60)
    )

label_panel <- textGrob(
    label = "Panel", x = 2.2, y = 0.115,
    gp = gpar(fontsize = 12, fontface  = "bold"),
    hjust = 1
)

label_chr <- textGrob(
    label = "Chromosome", x = 2.2, y = 0.05,
    gp = gpar(fontsize = 12, fontface  = "bold"),
    hjust = 1
)

# Combine them into one grob tree
side_labels <- grobTree(label_panel, label_chr)

png("article/phasing_accuracy.png", width = 800, height = 400)
grid.arrange(
    arrangeGrob(side_labels, p, ncol = 2, widths = unit.c(unit(3, "lines"), unit(1, "npc") - unit(3, "lines")))
)
dev.off()
