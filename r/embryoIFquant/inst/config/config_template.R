# Configuration for embryoIFquant::run_experiment()
# Copy this file next to your data, edit it, then run:
#   Rscript -e 'embryoIFquant::run_experiment("config.R")'
# Relative paths are taken relative to this file.

experiment <- "Example: mark + H3 + DAPI, three genotypes"
data_dir   <- "intensity_tables"          # folder with <image>.tif_intensity.csv files
out_dir    <- "results"

# Fiji channel -> marker. Check against the image: cropping can drop and renumber channels.
channels   <- c(C1 = "H3", C2 = "MARK", C3 = "DAPI")

# Ordered regex -> genotype, matched on the file name; the first match wins.
genotype_rules <- c(WT = "^WT_", MutA = "^MutA_", MutB = "^MutB_")
control    <- "WT"

# Within-nucleus ratios, "numerator / denominator"
ratios     <- c("MARK / H3", "MARK / DAPI", "H3 / DAPI")

# Readouts that should not change between genotypes; a change is flagged in the log
control_readouts <- c("H3", "DAPI", "H3 / DAPI")

# Optional settings (defaults shown)
# exclude_files <- character(0)            # regexes of files to skip
# session_rules <- NULL                    # e.g. c(slide1 = "^WT_", slide2 = "^WT2_", mid = ".")
# saturation    <- 65000                   # 16-bit saturation
# area_quantile <- c(0.005, 0.995)         # nuclear area range kept
# centre        <- "median"                # nucleus -> image -> embryo summary
# mixed_model   <- TRUE                    # lmerTest check on all nuclei
# show_p        <- FALSE                   # print P values on the superplots
# plot_family   <- ""                      # e.g. "Arial" or "Times New Roman"
# palette       <- c(WT = "#4D4D4D", MutA = "#E69F00", MutB = "#0072B2")
