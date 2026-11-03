test_that("validation catches duplicate poll results", {
  polls <- tibble::tibble(
    poll_id = "1",
    election_key = "congreso_espana_2026",
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
    election_key = "congreso_espana_2026",
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

test_that("validation checks the configured average election", {
  election_key <- "congreso_espana_2026"
  polls <- tibble::tibble(
    poll_id = "1",
    election_key = election_key,
    pollster_key = "demo",
    pollster_name = "Demo",
    media = "Demo",
    fieldwork_start = as.Date("2026-10-30"),
    fieldwork_end = as.Date("2026-10-31"),
    publication_date = as.Date("2026-11-01"),
    sample_size = 1000,
    sample_size_imputed = FALSE
  )
  poll_results <- polls |>
    dplyr::mutate(
      party_key = "psoe",
      party_name = "PSOE",
      short_name = "PSOE",
      color_hex = "#e30613",
      vote_share = 30
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
    election_key = election_key,
    current_date = as.Date("2026-11-03"),
    freshness_days = 45
  )

  expect_equal(report$checks$recent_next_election_poll$status, "pass")
  expect_equal(report$status, "passed")
})

test_that("recent-poll validation handles an election with no dated polls", {
  polls <- tibble::tibble(
    election_key = character(),
    fieldwork_end = as.Date(character())
  )

  expect_warning(
    check <- check_recent_poll(
      polls,
      election_key = "congreso_espana_2026",
      current_date = as.Date("2026-11-03"),
      freshness_days = 45
    ),
    NA
  )

  expect_equal(check$status, "fail")
  expect_match(check$message, "no polls with a non-missing fieldwork_end")
})

test_that("failed validation errors include the check message", {
  report <- list(
    status = "failed",
    checks = list(
      recent_next_election_poll = list(
        status = "fail",
        severity = "error",
        message = paste(
          "no polls with a non-missing fieldwork_end for",
          "congreso_espana_2026"
        )
      )
    )
  )

  expect_error(
    assert_validation_ok(report),
    paste(
      "recent_next_election_poll",
      ".*no polls with a non-missing fieldwork_end for",
      "congreso_espana_2026"
    )
  )
})
