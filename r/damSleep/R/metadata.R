# Metadata (plate layout) and monitor-file utilities.
# Author: Khushi Singh

#' Read and clean a DAM metadata table
#'
#' The metadata has one row per monitor channel with at least the columns
#' `file` (monitor file name, e.g. `Monitor1.txt`), `region_id` (channel 1-32),
#' `start_datetime` and `stop_datetime` (`"YYYY-MM-DD hh:mm:ss"`; the time of
#' `start_datetime` is ZT0, lights-on), a genotype column and `sex`. Tables
#' saved by Excel with `;` as separator are read as well.
#'
#' The genotype column is renamed to `genotype`, which the rest of the package
#' uses. Empty columns (e.g. an unused `indiv.` column) and empty wells are
#' removed.
#'
#' @param path Path of the metadata file (`.csv`, comma or semicolon separated).
#' @param group_col Name of the genotype column in the file (often `condition`).
#' @param empty Values that mark an empty well in the genotype or `sex` column.
#' @param recode Named character vector of label corrections, e.g.
#'   `c(mutAA = "mutA")`.
#' @param start_datetime,stop_datetime Optional values that replace the dates in
#'   the file for every row.
#' @return A `data.table` with one row per used channel.
#' @export
#' @examples
#' f <- tempfile(fileext = ".csv")
#' writeLines(c("file;region_id;start_datetime;stop_datetime;condition;sex;indiv.",
#'              "Monitor1.txt;1;2026-09-29 09:00:00;2026-10-02 09:00:00;WT;M;",
#'              "Monitor1.txt;2;2026-09-29 09:00:00;2026-10-02 09:00:00;;;"), f)
#' read_dam_metadata(f)
read_dam_metadata <- function(path, group_col = "condition", empty = c("", "NA", "EMPTY"),
                              recode = NULL, start_datetime = NULL, stop_datetime = NULL) {
  md <- data.table::fread(path, sep = "auto", colClasses = "character", na.strings = NULL)
  md <- md[, which(vapply(md, function(x) any(!is.na(x) & trimws(x) != ""), logical(1))), with = FALSE]
  required <- c("file", "region_id", "start_datetime", "stop_datetime", group_col, "sex")
  missing <- setdiff(required, names(md))
  if (length(missing)) stop("metadata is missing the column(s): ", paste(missing, collapse = ", "))
  if (group_col != "genotype") data.table::setnames(md, group_col, "genotype")
  for (col in names(md)) data.table::set(md, j = col, value = trimws(md[[col]]))
  md <- md[!(genotype %in% empty | is.na(genotype) | sex %in% empty | is.na(sex))]
  if (length(recode)) {
    hit <- md$genotype %in% names(recode)
    md[hit, genotype := unname(recode[genotype])]
  }
  if (!is.null(start_datetime)) md[, start_datetime := start_datetime]
  if (!is.null(stop_datetime)) md[, stop_datetime := stop_datetime]
  md[, region_id := as.integer(region_id)]
  unique(md)
}

#' Write an empty metadata table for a DAM experiment
#'
#' One row per channel of every monitor, to be filled in with the genotype and
#' sex of each fly (leave both empty for an empty tube).
#'
#' @param files Monitor file names, e.g. `sprintf("Monitor%d.txt", 1:6)`.
#' @param start_datetime,stop_datetime Start (lights-on, ZT0) and end of the
#'   recording, `"YYYY-MM-DD hh:mm:ss"`.
#' @param channels Channels per monitor.
#' @param path Optional output file (`.csv`).
#' @return The table, invisibly when `path` is given.
#' @export
#' @examples
#' make_metadata_template(c("Monitor1.txt", "Monitor2.txt"),
#'                        "2026-09-29 09:00:00", "2026-10-06 09:00:00")[1:3]
make_metadata_template <- function(files, start_datetime, stop_datetime, channels = 1:32, path = NULL) {
  md <- data.table::CJ(file = files, region_id = as.integer(channels), sorted = FALSE)
  md[, `:=`(start_datetime = start_datetime, stop_datetime = stop_datetime, genotype = "", sex = "")]
  if (is.null(path)) return(md)
  data.table::fwrite(md, path)
  invisible(md)
}

#' Shift the dates in a DAM monitor file
#'
#' Rewrites the date column (`"29 Sep 26"`, `"1 Oct 26"`) of a DAM2 monitor file by a whole
#' number of days, keeping the clock times. Use it when the computer that
#' recorded the monitors had the wrong date. The input file is never changed.
#'
#' @param in_file Monitor file to read.
#' @param out_file File to write; must differ from `in_file`.
#' @param from_date,to_date The recorded date and the correct date of the same
#'   day (`"YYYY-MM-DD"`); every row is shifted by their difference.
#' @param overwrite Allow `out_file` to be replaced if it exists.
#' @return The number of days shifted, invisibly.
#' @export
shift_monitor_dates <- function(in_file, out_file, from_date, to_date, overwrite = FALSE) {
  if (normalizePath(in_file, mustWork = TRUE) == normalizePath(out_file, mustWork = FALSE))
    stop("out_file must differ from in_file: the raw monitor file is never changed")
  if (file.exists(out_file) && !overwrite) stop(out_file, " exists; set overwrite = TRUE to replace it")
  shift <- as.integer(as.Date(to_date) - as.Date(from_date))
  old <- Sys.getlocale("LC_TIME")
  on.exit(Sys.setlocale("LC_TIME", old), add = TRUE)
  Sys.setlocale("LC_TIME", "C")
  x <- data.table::fread(in_file, sep = "\t", header = FALSE, colClasses = "character")
  d <- as.Date(x[[2]], format = "%d %b %y")
  if (anyNA(d)) stop("unreadable dates in ", in_file)
  data.table::set(x, j = 2L, value = sub("^0", "", format(d + shift, "%d %b %y")))   # DAM writes "1 Oct 26"
  data.table::fwrite(x, out_file, sep = "\t", col.names = FALSE, quote = FALSE)
  invisible(shift)
}
