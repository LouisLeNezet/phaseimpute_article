library(ggplot2)
library(dplyr)
library(tidyr)

setwd("/projects/dog/llenezet/script/benchmark/article")
source("functions.R")

# Panel simulate
all_df <- list()
for (i in c(0.1, 0.2, 0.5, 1, 2, 4)) { #, 8)) {
    path <- paste0("/projects/dog/llenezet/script/benchmark/results_simulate_", i, "/pipeline_info")
    # list all files in the directory
    files <- list.files(path, full.names = TRUE)
    # Keep only files starting by co2footprint_trace_
    files <- files[grep("co2footprint_trace_", files)]
    # Keep only last generated files based on the date
    files <- files[which.max(file.info(files)$ctime)]
    # Read the file
    all_df[[as.character(i)]] <- read.table(files, header = TRUE, row.names = 1, sep = "\t")
}

df <- data.table::rbindlist(all_df, idcol = "simu")

# Convert units
df$CO2e <- convert_co2e(df$CO2e)
df$energy_consumption <- convert_energy(df$energy_consumption)
df$time <- convert_time(df$time) / 60

df$Process <- NA
df$Process[grepl("CHRCHECK_INPUT", df$name)] <- "Initialisation"
df$Process[grepl("SAMTOOLS_COVERAGE", df$name)] <- "Statistics"
df$Process[grepl("BAM_DOWNSAMPLE_SAMTOOL", df$name)] <- "Downsampling"
df$Process[grepl("FILTER_CHR_", df$name)] <- "Statistics"
df$Process[grepl("MULTIQC", df$name)] <- "MultiQC"
df$Process <- factor(df$Process, levels = c("Initialisation", "Downsampling", "Statistics", "MultiQC"), ordered = TRUE)

df$name[is.na(df$Process)]
df$simu <- factor(df$simu, levels = c(0.1, 0.2, 0.5, 1, 2, 4), ordered = TRUE)

df2 <- df %>%
    group_by(simu) %>%
    summarise(
        TimeCPUe = sum(time * cpus * cpu_usage),
        TimeCPU = sum(time * cpus),
        Time = sum(time),
    ) %>%
    mutate(
        simu_n = as.numeric(as.character(simu))
    )

model <- lm(TimeCPUe ~ I(simu_n) + I(simu_n^2), data = df2)
summary(model) # y = 80.6 + 4.9 * x - 0.14 * x^2

model1 <- lm(TimeCPU ~ I(simu_n) + I(simu_n^2), data = df2)
summary(model1) # y = 254.34 + 1.11 * x + 0.65 * x^2

model2 <- lm(Time ~ I(simu_n) + I(simu_n^2), data = df2)
summary(model2) # y = 179.96 + 1.05 * x - 0.32 * x^2

pred_df <- data.frame(simu_n = seq(0.1, 4, by = 0.1))
pred_df$Time <- predict(model, newdata = pred_df["simu_n"])
coefs <- coef(model)
eq_label <- sprintf("Time = %.2f + %.2f*x + %.2f*x²", coefs[1], coefs[2], coefs[3])

png("panel_simulate_cpu.png", width=800, height=400)
p1 <- ggplot(df2, aes(x = as.numeric(as.character(simu)))) +
    geom_line(data = pred_df, aes(x = simu_n, y = Time), color = "red", linewidth = 1.2) +
    geom_point(aes(y = TimeCPUe)) +
    scale_x_continuous(
        name = "Genome coverage depth simulated",
        breaks = c(0.1, 0.5, 1, 2, 4)
    ) +
    labs(
        y = "Effective CPU Time (min)"
    ) +
    annotate("text", x = max(df2$simu_n) * 0.5, y = max(df2$TimeCPUe), label = eq_label, hjust = 0, size = 5) +
    theme_minimal(base_size = 15)
p1
dev.off()

df2 <- df %>%
    group_by(simu) %>%
    summarise(
        Time = sum(time),
        CO2e = sum(CO2e),
        Energy = sum(energy_consumption),

    ) %>%
    pivot_longer(
        cols = c("CO2e", "Energy", "Time"),
        names_to = "metric", values_to = "value"
    )

# Plot metrics
breaks <- c(1, 2, 5, 10, 20, 50, 100, 200, 500, 1000)
png("panel_simulate.png", width=800, height=400)
plot_benchmark(
    data_benchmark = df2, fill = "simu",
    base = 10, sigma = 1, breaks = breaks,
    x = "simu", x_label = "Genome coverage depth simulated"
) +
    theme(
        legend.title = element_blank(),
    )
dev.off()

## Divide by process
df2 <- df %>%
    group_by(Process, simu) %>%
    summarise(
        Time = sum(time),
        CO2e = sum(CO2e),
        Energy = sum(energy_consumption),

    ) %>%
    pivot_longer(
        cols = c("CO2e", "Energy", "Time"),
        names_to = "metric", values_to = "value"
    )

# Plot metrics log y angle 45 for x
png("panel_simulate_process.png", width=800, height=400)
p2 <- plot_benchmark(
    data_benchmark = df2, fill = "simu",
    base = 10, sigma = 1, breaks = breaks,
    x = "Process", x_label = "Process"
) +
    theme(
        legend.title = element_blank(),
    )
p2
dev.off()

png("panel_simulate_process_cpu.png", width=1400, height=500)
aligned_plot <- p1 + p2 + plot_layout(ncol = 2)

aligned_plot
dev.off()
