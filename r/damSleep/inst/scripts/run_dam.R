#!/usr/bin/env Rscript
# Run a DAM sleep and activity analysis from a configuration file.
# Usage: Rscript run_dam.R dam_config.R
# Author: Khushi Singh
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) stop("usage: Rscript run_dam.R <config.R>")
damSleep::run_dam_experiment(args[1])
