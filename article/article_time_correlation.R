library(ggplot2)
library(dplyr)
library(tidyr)
library(stringr)
library(data.table)
library(ggpmisc)

setwd("/projects/dog/llenezet/script/benchmark")
source("article/functions.R")

all_df <- list()

for (test in c(
    "phasing_full", "phasing_half", "panelprep", "impute",
    "simulate_0.1", "simulate_0.2", "simulate_0.5",
    "simulate_1", "simulate_2", "simulate_4",# "simulate_8",
    "validate"
)) {
    path <- paste0(
        "/projects/dog/llenezet/script/benchmark/results_",
        test,
        "/pipeline_info"
    )
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
    df$Energy <- convert_energy(df$energy_consumption)
    df$Time <- convert_time(df$time) / 60

    all_df[[test]] <- df
}

# Bind all dataframes together
df <- rbindlist(all_df, idcol = "test")

df[df$Time > 70, ]
df$cpu_effective <- df$cpus * df$cpu_usage
df$cpu_effective_f <- cut(df$cpu_effective, breaks = c(0, 0.5, 1.5, 2.5, 3.5, 4.5, 5.5, 6))
df$powerdraw_cpu <- 12

resume_df <- df %>%
    group_by(test) %>%
    summarise(
        cpu_m = round(mean(cpu_effective), 2),
        cpu_sd = round(sd(cpu_effective), 2),
        time = round(sum(Time*cpus) / 60, 2)
    )

resume_df %>%
    filter(str_detect(test, "simulate")) %>%
    summarise(
        cpu_m = round(mean(cpu_m), 2),
        cpu_sd = round(mean(cpu_sd), 2),
        time_sd = round(sd(time), 2),
        time_total = sum(time),
        time = round(mean(time), 2),
    )

write.table(
    resume_df,
    "article/cpu_effective.csv", row.names = FALSE,
    quote = FALSE, sep = "\t"
)

df2 <- df %>%
    pivot_longer(
        cols = c("CO2e", "Energy"),
        names_to = "metric", values_to = "value"
    )

png("article/correlation_matrix.png", width = 1800, height = 1400)
ggplot(df2, aes(x = Time, y = value, colour = cpu_effective_f)) +
    geom_point() +
    labs(
        x = "Time (min)",
        y = "Value",
        title = "Correlation between Time and CO2e / Energy consumption"
    ) +
    theme_minimal(base_size = 15) +
    theme(
        legend.title = element_blank(),
    ) +
    stat_poly_line() +
    stat_poly_eq(
        formula = y ~ 0 + x,
        parse = TRUE, size = 5,
        use_label(c("eq", "R2"))
    ) +
    facet_wrap(~ metric, scales = "free")
dev.off()
