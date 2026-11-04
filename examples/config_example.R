# Configuration for the synthetic example (run examples/make_synthetic_data.py first).
# Run from the repository root:  Rscript -e 'embryoIFquant::run_experiment("examples/config_example.R")'

experiment <- "Synthetic example: MARK + H3 + DAPI"
data_dir   <- "data/intensity_tables"
out_dir    <- "out"
channels   <- c(C1 = "H3", C2 = "MARK", C3 = "DAPI")
genotype_rules <- c(WT = "^WT_", MutA = "^MutA_", MutB = "^MutB_")
control    <- "WT"
ratios     <- c("MARK / H3", "MARK / DAPI", "H3 / DAPI")
mixed_model <- FALSE
