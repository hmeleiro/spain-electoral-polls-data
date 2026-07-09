test_that("kalman_daily handles sparse data", {
  df <- tibble::tibble(
    date = as.Date(c("2026-01-01", "2026-01-02")),
    vote_share = c(30, 31),
    sample_size_weight = c(1000, 1000)
  )

  out <- kalman_daily(df)

  expect_equal(nrow(out), 2)
  expect_true(all(is.na(out$average_vote_share)))
})

test_that("kalman_daily aggregates multiple polls per day with weights", {
  df <- tibble::tibble(
    date = as.Date(c("2026-01-01", "2026-01-01", "2026-01-03")),
    vote_share = c(20, 30, 40),
    sample_size_weight = c(1, 3, 1)
  )

  out <- kalman_daily(df)

  expect_equal(min(out$date), as.Date("2026-01-01"))
  expect_equal(max(out$date), as.Date("2026-01-03"))
  expect_equal(out$n_polls_day[out$date == as.Date("2026-01-01")], 2)
})
