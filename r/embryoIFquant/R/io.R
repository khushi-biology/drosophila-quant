# Reading Fiji intensity tables and parsing image file names.
# Author: Khushi Singh

#' Read every Fiji intensity table in a folder
#'
#' Reads the tables written by Fiji's ROI Manager (*Multi Measure*), one per
#' image, named `<image stem>.tif_intensity.csv`. Each table has the columns
#' `" "`, `Label`, `Area`, `Mean`, `Min`, `Max`, with one row per nucleus and
#' channel and labels of the form `<image stem>.tif_ROI<k>_C<n>`.
#'
#' @param dir Folder containing the `*.tif_intensity.csv` files.
#' @param exclude Character vector of regular expressions; files whose name
#'   matches any of them are skipped (e.g. a slide imaged late in a session).
#' @param pattern File-name pattern of the intensity tables.
#' @return A tibble with columns `file`, `Label`, `area`, `mean`, `min`, `max`.
#' @export
read_intensity_folder <- function(dir, exclude = character(0),
                                  pattern = "\\.tif_intensity\\.csv$") {
  files <- list.files(dir, pattern = pattern, full.names = TRUE)
  for (x in exclude) files <- files[!stringr::str_detect(basename(files), x)]
  if (!length(files)) stop("no *_intensity.csv files in ", dir)
  purrr::map_dfr(files, read_intensity_table)
}

#' Read one Fiji intensity table
#'
#' @param file Path of a `*.tif_intensity.csv` table.
#' @return A tibble with columns `file`, `Label`, `area`, `mean`, `min`, `max`.
#' @export
read_intensity_table <- function(file) {
  d <- readr::read_csv(file, show_col_types = FALSE,
                       col_types = readr::cols(.default = "c"), name_repair = "minimal")
  need <- c("Label", "Area", "Mean", "Min", "Max")
  miss <- setdiff(need, names(d))
  if (length(miss)) stop(basename(file), ": missing column(s) ", paste(miss, collapse = ", "))
  tibble::tibble(file = basename(file), Label = d$Label,
                 area = as.numeric(d$Area), mean = as.numeric(d$Mean),
                 min = as.numeric(d$Min), max = as.numeric(d$Max))
}

#' Assign labels from ordered regular-expression rules
#'
#' The first rule that matches wins, which makes prefixes that contain one
#' another safe (for example `W` and `W2`, or `MUT` and `MUT1`), provided the
#' more specific rule is listed first or the patterns are anchored.
#'
#' @param x Character vector to classify.
#' @param rules Named character vector, `label = regex`.
#' @return Character vector of labels (`NA` where no rule matches).
#' @export
match_rules <- function(x, rules) {
  out <- rep(NA_character_, length(x))
  for (k in seq_along(rules)) {
    hit <- is.na(out) & stringr::str_detect(x, rules[[k]])
    out[hit] <- names(rules)[k]
  }
  out
}

#' Parse genotype, embryo, image, ROI and channel from file names and labels
#'
#' The genotype is taken from `genotype_rules` (see [match_rules()]). Embryo
#' and image are read from the number block before `.tif`:
#'
#' * `..._4-1.tif`       embryo 4, image 1 (one crop per field)
#' * `..._4-1-2.tif`     embryo 4, field 1, crop 2
#' * `..._6.2-1-1.tif`   embryo "6.2" (decimal identifiers are kept as text)
#' * `..._3.2_czi-1.tif` and `..._snap_1-1.tif` are also recognised
#'
#' @param d Output of [read_intensity_folder()].
#' @param genotype_rules Named character vector, `genotype = regex`.
#' @param session_rules Optional named character vector, `session = regex`.
#' @return `d` with columns `genotype`, `session`, `embryo_id`, `embryo`,
#'   `image`, `roi` and `channel` added.
#' @export
parse_names <- function(d, genotype_rules, session_rules = NULL) {
  stem <- stringr::str_remove(d$file, "_intensity\\.csv$")
  num <- stringr::str_match(stem, "_(\\d+(?:\\.\\d+)?)(?:_czi)?-(\\d+)(?:-(\\d+))?\\.tif$")
  geno <- match_rules(stem, genotype_rules)
  if (anyNA(geno))
    stop("no genotype rule matches: ", paste(unique(d$file[is.na(geno)]), collapse = ", "))
  if (anyNA(num[, 2]))
    stop("cannot read embryo/image from: ", paste(unique(d$file[is.na(num[, 2])]), collapse = ", "))
  ses <- if (is.null(session_rules)) NA_character_ else match_rules(stem, session_rules)
  dplyr::mutate(d,
    genotype = geno, session = ses,
    embryo_id = num[, 2],
    embryo = paste(.data$genotype, .data$embryo_id, sep = "_"),
    image = paste(.data$embryo, num[, 3], ifelse(is.na(num[, 4]), "1", num[, 4]), sep = "_"),
    roi = as.integer(stringr::str_match(.data$Label, "_ROI(\\d+)_C\\d+$")[, 2]),
    channel = paste0("C", stringr::str_match(.data$Label, "_C(\\d+)$")[, 2]))
}
