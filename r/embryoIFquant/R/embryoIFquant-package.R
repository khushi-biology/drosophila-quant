# Package documentation.
# Author: Khushi Singh

#' embryoIFquant: embryo-level quantification of nuclear immunofluorescence
#'
#' The workflow, in order of use:
#'
#' 1. [read_intensity_folder()] and [parse_names()] read the Fiji tables and
#'    the genotype / embryo / image structure from the file names.
#' 2. [to_nuclei()] and [qc_nuclei()] build the per-nucleus table and flag
#'    saturated nuclei and area outliers.
#' 3. [make_long()] forms raw and within-nucleus ratio readouts and
#'    [embryo_values()] summarises nuclei to images to embryos.
#' 4. [welch_vs_control()] (with the [mixed_vs_control()] check) gives the
#'    genotype effects; [combine_experiments()] combines sessions.
#' 5. [superplot()] and [forest_plot()] draw the results.
#'
#' [run_experiment()] runs steps 1-5 from one configuration file.
#'
#' @keywords internal
#' @importFrom rlang .data
"_PACKAGE"

utils::globalVariables(c("value", "genotype", "embryo", "image", "log2rel", "experiment"))
