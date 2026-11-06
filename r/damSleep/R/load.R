# Loading monitor files, removing dead animals and trimming.
# Author: Khushi Singh

#' Load DAM recordings with sleep annotation
#'
#' Links the metadata to the monitor files ([damr::link_dam_metadata()]) and
#' loads them ([damr::load_dam()]) with [sleepr::sleep_dam_annotation()], which
#' adds the columns `moving` and `asleep`: a fly is asleep during any
#' immobility of at least `min_immobile_min` minutes.
#'
#' @param metadata Metadata from [read_dam_metadata()].
#' @param result_dir Folder that contains the monitor files.
#' @param genotype_levels Order of the genotypes in tables and plots (default:
#'   order of first appearance).
#' @param sex_levels Order of the sexes.
#' @param min_immobile_min Minimum immobility (min) that counts as sleep.
#' @return A `behavr` table: one row per fly and time bin, `t` in seconds from
#'   ZT0, with metadata columns `genotype` and `sex`.
#' @export
load_dam_sleep <- function(metadata, result_dir, genotype_levels = NULL,
                           sex_levels = c("F", "M"), min_immobile_min = 5) {
  md <- damr::link_dam_metadata(data.table::copy(metadata), result_dir = result_dir)
  dt <- damr::load_dam(md, FUN = sleepr::sleep_dam_annotation, min_time_immobile = min_immobile_min * 60)
  if (nrow(dt) == 0)
    stop("no data loaded: start_datetime/stop_datetime in the metadata do not overlap ",
         "the dates recorded in the monitor files")
  if (is.null(genotype_levels)) genotype_levels <- unique(metadata$genotype)
  sex_levels <- union(sex_levels, unique(metadata$sex))
  m <- data.table::copy(dt[meta = TRUE])
  m[, genotype := factor(genotype, levels = genotype_levels)]
  m[, sex := factor(sex, levels = sex_levels)]
  behavr::setmeta(dt, m)
  dt
}

#' Median sampling interval of a recording
#'
#' @param dt A `behavr` table.
#' @return The bin length in seconds (e.g. 30 or 60).
#' @export
bin_seconds <- function(dt) {
  as.numeric(dt[, list(d = stats::median(diff(t))), by = id][, stats::median(d)])
}

#' Remove dead animals and trim to the analysis window
#'
#' [sleepr::curate_dead_animals()] calls a fly dead after 24 h of (almost)
#' complete immobility. Near the end of a recording this mistakes a long final
#' sleep for death, because there are no later data to show that the fly woke
#' up. This function therefore
#'
#' * removes flies that were dead or inactive from the start;
#' * accepts a death call only when it is at least `end_tolerance_days` before
#'   the end of the analysis window, and keeps such flies until their death if
#'   they lived longer than `min_lifespan_days`;
#' * restores the full data of flies whose death call falls closer to the end
#'   (trailing sleep, not death);
#' * removes flies that lived `min_lifespan_days` or less;
#' * trims everything to `[0, analysis_days]` days from ZT0.
#'
#' @param dt A `behavr` table from [load_dam_sleep()].
#' @param analysis_days Length of the analysed window (days from ZT0).
#' @param min_lifespan_days Flies that lived this long or less are removed.
#' @param end_tolerance_days Death calls closer than this to the end of the
#'   window are treated as trailing sleep.
#' @return A list with `data` (the curated `behavr` table) and `excluded` (one
#'   row per removed, truncated or restored fly with the reason).
#' @export
curate_animals <- function(dt, analysis_days, min_lifespan_days = 2, end_tolerance_days = 1) {
  end_t <- days(analysis_days)
  curated <- sleepr::curate_dead_animals(dt)
  dead_at_start <- setdiff(dt[, id, meta = TRUE], curated[, id, meta = TRUE])
  lifespan_dt <- curated[, list(lifespan = max(t)), by = id]
  died_mid <- lifespan_dt[lifespan < end_t - days(end_tolerance_days), id]
  end_artefact <- lifespan_dt[lifespan >= end_t - days(end_tolerance_days) & lifespan < end_t - mins(1), id]
  life <- stats::setNames(lifespan_dt$lifespan, as.character(lifespan_dt$id))

  out <- dt[id %in% lifespan_dt$id]
  out <- out[!(id %in% died_mid) | t <= life[as.character(id)]]
  valid <- lifespan_dt[lifespan > days(min_lifespan_days), id]
  died_early <- setdiff(lifespan_dt$id, valid)
  died_later <- setdiff(died_mid, died_early)
  out <- out[id %in% valid]
  out <- out[t >= 0 & t <= end_t]

  excluded <- rbind(
    data.table(id = as.character(dead_at_start), reason = "Dead or inactive from the start"),
    data.table(id = as.character(died_early),
               reason = sprintf("Died within the first %g days (removed)", min_lifespan_days)),
    data.table(id = as.character(died_later), reason = "Died later (kept, data truncated at death)"),
    data.table(id = as.character(end_artefact),
               reason = "Trailing sleep at the end mistaken for death; full data restored"))
  meta <- dt[meta = TRUE]
  meta <- data.table(id = as.character(meta$id),
                     file = basename(vapply(meta$file_info, function(x) x$path, character(1))),
                     region_id = meta$region_id, genotype = meta$genotype, sex = meta$sex)
  excluded <- merge(excluded, meta, by = "id")
  excluded[, curated_lifespan_h := round(unname(life[id]) / 3600, 2)]
  excluded[, hours_trimmed_by_curation := round((end_t - unname(life[id])) / 3600, 2)]
  data.table::setorder(excluded, reason, -hours_trimmed_by_curation)
  list(data = out, excluded = excluded[])
}

#' Number of flies loaded and analysed per group
#'
#' @param loaded The table from [load_dam_sleep()].
#' @param analysed The curated table (`curate_animals(...)$data`).
#' @return A `data.table` with `genotype`, `sex`, `loaded`, `analysed`.
#' @export
sample_sizes <- function(loaded, analysed) {
  a <- loaded[meta = TRUE][, list(loaded = .N), by = list(genotype, sex)]
  b <- analysed[meta = TRUE][, list(analysed = .N), by = list(genotype, sex)]
  s <- merge(a, b, by = c("genotype", "sex"), all = TRUE)
  s[is.na(analysed), analysed := 0L]
  data.table::setorder(s, genotype, sex)
  s[]
}
