test_that("validation catches duplicate poll results", {
  polls <- tibble::tibble(
    poll_id = "1",
    election_key = "congreso_espana_2027",
    pollster_key = "demo",
    pollster_name = "Demo",
    media = "Demo",
    fieldwork_start = as.Date("2026-07-01"),
    fieldwork_end = as.Date("2026-07-02"),
    publication_date = as.Date("2026-07-03"),
    sample_size = 1000,
    sample_size_imputed = FALSE
  )
  poll_results <- tibble::tibble(
    poll_id = c("1", "1"),
    election_key = "congreso_espana_2027",
    pollster_key = "demo",
    pollster_name = "Demo",
    media = "Demo",
    fieldwork_start = as.Date("2026-07-01"),
    fieldwork_end = as.Date("2026-07-02"),
    publication_date = as.Date("2026-07-03"),
    sample_size = 1000,
    sample_size_imputed = FALSE,
    party_key = c("psoe", "psoe"),
    party_name = "PSOE",
    short_name = "PSOE",
    color_hex = "#e30613",
    vote_share = c(30, 31)
  )
  artifacts <- list(
    polls = polls,
    poll_results = poll_results,
    poll_average_daily = tibble::tibble(),
    poll_deviations = tibble::tibble(),
    house_effects = tibble::tibble(),
    manifest = list()
  )

  report <- validate_public_artifacts(
    artifacts,
    current_date = as.Date("2026-07-07"),
    freshness_days = 45
  )

  expect_equal(report$checks$duplicate_poll_results$status, "fail")
  expect_equal(report$status, "failed")
})
