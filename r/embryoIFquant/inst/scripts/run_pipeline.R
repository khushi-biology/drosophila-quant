#!/usr/bin/env Rscript
# Run the embryoIFquant pipeline from the command line.
# Usage:  Rscript run_pipeline.R config.R [config2.R ...]
# Author: Khushi Singh

args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) stop("usage: Rscript run_pipeline.R config.R [config2.R ...]")
for (cfg in args) {
  message("== ", cfg)
  embryoIFquant::run_experiment(cfg)
}
