# Convert time to seconds
convert_time <- function(x) {
    x <- gsub("ms", "e-3", x)
    x <- gsub("s", "", x)
    x <- gsub("m", "*60", x)
    x <- gsub("h", "*3600", x)
    x <- gsub(" ", "+", x)
    x <- unname(sapply(x, function(xi) {
        eval(parse(text = xi))
    }))
    return (x)
}

# Convert energy to Wh
convert_energy <- function(x) {
    x <- gsub("uWh", "e-6", x)
    x <- gsub("mWh", "e-3", x)
    x <- gsub("pWh", "e-12", x)
    x <- gsub("Wh", "", x)
    x <- gsub(" ", "", x)
    return(as.numeric(x))
}

# Convert CO2e to g
convert_co2e <- function(x) {
    x <- gsub("pg", "e-12", x)
    x <- gsub("ng", "e-9", x)
    x <- gsub("ug", "e-6", x)
    x <- gsub("mg", "e-3", x)
    x <- gsub("g", "", x)
    x <- gsub(" ", "", x)
    return(as.numeric(x))
}

library(cowplot)
library(patchwork)
library(ggplot2)
library(dplyr)

plot_benchmark <- function(
    data_benchmark, fill = "chr",
    base = 10, x = "Process", x_label = "Process",
    sigma = 1, breaks = NULL
) {
    common_theme <- theme_minimal(base_size = 15) +
        theme(
            axis.text.x = element_text(angle = 45, hjust = 1),
            axis.line = element_line(),
            axis.ticks = element_line(),
        )
    p_co2e <- ggplot(
        data_benchmark %>% filter(metric == "CO2e"),
        aes(x = !!sym(x), y = value, fill = !!sym(fill))
    ) +
        geom_col(position = position_dodge2(preserve = "single")) +
        scale_y_continuous(
            name = "CO2e (g)",
            trans = scales::pseudo_log_trans(base = base, sigma = sigma),
            breaks = breaks, limits = c(0, NA)
        ) +
        common_theme
    p_energy <- ggplot(
        data_benchmark %>% filter(metric == "Energy"),
        aes(x = !!sym(x), y = value, fill = !!sym(fill))
    ) +
        geom_col(position = position_dodge2(preserve = "single")) +
        scale_y_continuous(
            name = "Energy (Wh)",
            trans = scales::pseudo_log_trans(base = base, sigma = sigma),
            breaks = breaks, limits = c(0, NA)
        ) +
        common_theme
    p_time <- ggplot(
        data_benchmark %>% filter(metric == "Time"),
        aes(x = !!sym(x), y = value, fill = !!sym(fill))
    ) +
        geom_col(position = position_dodge2(preserve = "single")) +
        scale_y_continuous(
            name = "Time (min)",
            trans = scales::pseudo_log_trans(base = base, sigma = sigma),
            breaks = breaks, limits = c(0, NA)
        ) +
        common_theme
    wrap_elements(get_plot_component(p_co2e, "ylab-l")) +
        wrap_elements(get_y_axis(p_co2e)) +
        wrap_elements(get_plot_component(p_energy, "ylab-l")) +
        wrap_elements(get_y_axis(p_energy)) +
        p_time +
        labs(fill = fill, x = x_label) +
        plot_layout(widths = c(3, 1, 3, 1, 40))
}
