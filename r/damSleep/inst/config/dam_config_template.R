# Configuration of a DAM sleep and activity analysis (damSleep::run_dam_experiment).
# Copy this file next to your data, edit it and run:
#   Rscript -e 'damSleep::run_dam_experiment("dam_config.R")'
# Settings left out keep the defaults of damSleep::dam_config_defaults().

data_dir   <- "path/to/experiment"     # Monitor*.txt and the metadata
metadata   <- "metadata.csv"           # file, region_id, start_datetime, stop_datetime, condition, sex
out_dir    <- "path/to/experiment/dam_results"
group_col  <- "condition"              # genotype column of the metadata

genotypes  <- c("WT", "w1118", "mutA", "mutB")   # plotting order
controls   <- c("WT", "w1118")
tests      <- c("mutA", "mutB")
extra_comparisons <- data.frame(group = "w1118", control = "WT")   # or NULL

recode     <- NULL                     # e.g. c(mutAA = "mutA") to fix typos in the metadata

# ZT0 (lights-on) is the time of start_datetime in the metadata.
analysis_days      <- 7
min_lifespan_days  <- 2
end_tolerance_days <- 1
min_immobile_min   <- 5
light_hours        <- 12
period_hours       <- 24
latency_day        <- 2
