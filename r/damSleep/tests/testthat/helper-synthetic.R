# Synthetic DAM2 recordings with known sleep, for the tests.
# Author: Khushi Singh

# One monitor, 1-min bins, ZT0 = 09:00 on 1 Jan 2026, `n_days` days.
# Channels 1-4 "WT", 5-8 "mut", 9-12 "ctl2" (alternating F/M):
#   light phase: active every minute (no sleep);
#   dark phase:  awake for `latency` min after lights-off, then asleep until
#                lights-on ("mut" sleeps only the last 6 h of the night).
# Channel 13 dead from the start, 14 dies at day 2.5, 15 dies at day 1.
# Channels 16-32 empty.
make_synthetic_dam <- function(dir, n_days = 4) {
  old <- Sys.getlocale("LC_TIME"); on.exit(Sys.setlocale("LC_TIME", old)); Sys.setlocale("LC_TIME", "C")
  t0 <- as.POSIXct("2026-01-01 09:00:00", tz = "UTC")
  times <- seq(t0 - 3600, t0 + n_days * 86400 + 3600, by = 60)
  zt_min <- as.numeric(difftime(times, t0, units = "mins"))
  phase_min <- zt_min %% 1440
  latency <- c(30, 45, 60, 75, 30, 45, 60, 75, 40, 50, 60, 70)
  act <- matrix(0L, length(times), 32)
  for (ch in 1:12) {
    awake <- phase_min < 720 | (phase_min >= 720 & phase_min < 720 + latency[ch])
    if (ch %in% 5:8) awake <- awake | (phase_min >= 720 & phase_min < 1080)
    act[, ch] <- ifelse(awake, 1L + (seq_along(times) + ch) %% 3L, 0L)
  }
  act[, 14] <- ifelse(phase_min < 720, 2L, 0L); act[zt_min > 2.5 * 1440, 14] <- 0L
  act[, 15] <- ifelse(phase_min < 720, 2L, 0L); act[zt_min > 1 * 1440, 15] <- 0L
  head <- data.frame(seq_along(times), format(times, "%d %b %y"), format(times, "%H:%M:%S"),
                     1L, 0L, 1L, 0L, "Ct", 0L, 0L)
  out <- cbind(head, as.data.frame(act))
  utils::write.table(out, file.path(dir, "Monitor1.txt"), sep = "\t", quote = FALSE,
                     row.names = FALSE, col.names = FALSE)
  geno <- c(rep(c("WT", "mut", "ctl2"), each = 4), "WT", "WT", "WT", rep("", 17))
  sex <- c(rep(c("F", "M"), 6), "F", "M", "F", rep("", 17))
  stop_dt <- format(t0 + n_days * 86400, "%Y-%m-%d %H:%M:%S")
  md <- data.frame(file = "Monitor1.txt", region_id = 1:32, start_datetime = "2026-01-01 09:00:00",
                   stop_datetime = stop_dt, condition = geno, sex = sex, `indiv.` = "", check.names = FALSE)
  utils::write.table(md, file.path(dir, "metadata.csv"), sep = ";", quote = FALSE, row.names = FALSE)
  invisible(dir)
}

synthetic_dir <- function() {
  d <- tempfile("dam_"); dir.create(d); make_synthetic_dam(d)
}
