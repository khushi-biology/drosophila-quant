test_that("match_rules uses the first matching rule", {
  expect_equal(match_rules(c("W2_a", "W_a", "MUT1_a"), c(WT = "^W2?_", MUT = "^MUT1?_")),
               c("WT", "WT", "MUT"))
  expect_true(is.na(match_rules("X_a", c(WT = "^W_"))))
})

test_that("parse_names reads embryo, image, ROI and channel", {
  d <- tibble::tibble(file = c("WT_s_4-1.tif_intensity.csv", "WT_s_6.2-1-2.tif_intensity.csv",
                               "WT_s_3.2_czi-1.tif_intensity.csv"),
                      Label = c("WT_s_4-1.tif_ROI7_C2", "WT_s_6.2-1-2.tif_ROI1_C1", "x.tif_ROI3_C3"))
  p <- parse_names(d, c(WT = "^WT_"))
  expect_equal(p$embryo_id, c("4", "6.2", "3.2"))
  expect_equal(p$image, c("WT_4_1_1", "WT_6.2_1_2", "WT_3.2_1_1"))
  expect_equal(p$roi, c(7L, 1L, 3L))
  expect_equal(p$channel, c("C2", "C1", "C3"))
})

test_that("parse_names stops on unknown genotypes", {
  d <- tibble::tibble(file = "X_s_1-1.tif_intensity.csv", Label = "X_s_1-1.tif_ROI1_C1")
  expect_error(parse_names(d, c(WT = "^WT_")), "no genotype rule")
})
