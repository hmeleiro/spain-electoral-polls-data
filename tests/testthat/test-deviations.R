test_that("build_poll_deviations joins daily averages", {
  poll_results <- tibble::tibble(
    poll_id = c("1", "2"),
    election_key = "congreso_espana_2027",
    party_key = "psoe",
    date = as.Date(c("2026-01-01", "2026-01-02")),
    vote_share = c(30, 32)
  )
  averages <- tibble::tibble(
    election_key = "congreso_espana_2027",
    party_key = "psoe",
    date = as.Date(c("2026-01-01", "2026-01-02")),
    average_vote_share = c(29, 33)
  )

  out <- build_poll_deviations(poll_results, averages)

  expect_equal(out$deviation_from_average, c(1, -1))
})
