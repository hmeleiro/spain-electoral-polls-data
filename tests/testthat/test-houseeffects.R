test_that("fit_house_effects returns the public schema", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("gratia")

  dates <- seq(as.Date("2025-01-01"), by = "month", length.out = 8)
  df <- tidyr::expand_grid(
    date = dates,
    pollster_name = c("a", "b", "c"),
    pollster_key = c("a", "b", "c"),
    party_key = c("psoe", "pp")
  ) |>
    dplyr::mutate(
      vote_share = dplyr::case_when(
        .data$party_key == "psoe" ~ 30,
        TRUE ~ 35
      ) + dplyr::case_when(
        .data$pollster_key == "a" ~ 1,
        .data$pollster_key == "b" ~ -1,
        TRUE ~ 0
      ) + as.numeric(.data$date - min(.data$date)) / 365,
      sample_size_weight = 1000
    )

  out <- suppressWarnings(fit_house_effects(df, min_polls_pollster_party = 5))

  expect_named(out, c(
    "pollster_key", "party_key", "house_effect", "se", "ic_low",
    "ic_high", "n", "house_effect_status"
  ))
})
