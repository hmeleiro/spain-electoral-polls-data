fit_house_effects <- function(ts, min_polls_pollster_party = 5L, k = 30L) {
  required <- c("date", "vote_share", "pollster_key", "party_key")
  assert_columns(ts, required, "house effects input")

  df_model <- ts |>
    dplyr::mutate(
      date = as.Date(.data$date),
      date_num = as.numeric(.data$date),
      vote_share = as.numeric(.data$vote_share),
      pollster_key = factor(.data$pollster_key),
      party_key = factor(.data$party_key),
      model_weight = dplyr::case_when(
        "sample_size_weight" %in% names(ts) &
          !is.na(.data$sample_size_weight) &
          .data$sample_size_weight > 0 ~ sqrt(.data$sample_size_weight),
        TRUE ~ 1
      )
    ) |>
    dplyr::filter(
      !is.na(.data$vote_share),
      !is.na(.data$date_num),
      !is.na(.data$pollster_key),
      !is.na(.data$party_key)
    )

  valid_pollster_party <- df_model |>
    dplyr::count(.data$pollster_key, .data$party_key, name = "n") |>
    dplyr::filter(.data$n >= min_polls_pollster_party)

  df_model <- df_model |>
    dplyr::semi_join(
      valid_pollster_party,
      by = c("pollster_key", "party_key")
    ) |>
    droplevels()

  if (
    nrow(df_model) == 0 ||
      dplyr::n_distinct(df_model$pollster_key) < 2 ||
      dplyr::n_distinct(df_model$party_key) < 1 ||
      dplyr::n_distinct(df_model$date_num) < 5
  ) {
    return(empty_house_effects())
  }

  if (!requireNamespace("mgcv", quietly = TRUE)) {
    stop("Package 'mgcv' is required to estimate house effects.", call. = FALSE)
  }
  if (!requireNamespace("gratia", quietly = TRUE)) {
    stop("Package 'gratia' is required to extract house effects.", call. = FALSE)
  }

  k_use <- min(k, max(5L, dplyr::n_distinct(df_model$date_num) - 1L))

  mod_house <- mgcv::gam(
    vote_share ~
      party_key +
      s(date_num, by = party_key, k = k_use) +
      s(pollster_key, party_key, bs = "re"),
    data = df_model,
    weights = model_weight,
    method = "REML"
  )

  raw_effects <- gratia::smooth_estimates(
    mod_house,
    select = "s(pollster_key,party_key)"
  )

  raw_effects |>
    dplyr::transmute(
      pollster_key = as.character(.data$pollster_key),
      party_key = as.character(.data$party_key),
      house_effect = .data$.estimate,
      se = .data$.se,
      ic_low = .data$house_effect - 1.96 * .data$se,
      ic_high = .data$house_effect + 1.96 * .data$se
    ) |>
    dplyr::left_join(
      df_model |>
        dplyr::count(.data$pollster_name, .data$pollster_key, .data$party_key, name = "n") |>
        dplyr::mutate(
          pollster_name = as.character(.data$pollster_name),
          pollster_key = as.character(.data$pollster_key),
          party_key = as.character(.data$party_key)
        ),
      by = c("pollster_key", "party_key")
    ) |>
    dplyr::mutate(
      house_effect_status = dplyr::case_when(
        .data$ic_low > 0 ~ "positive",
        .data$ic_high < 0 ~ "negative",
        TRUE ~ "unclear"
      )
    ) |>
    dplyr::arrange(.data$party_key, dplyr::desc(abs(.data$house_effect))) |>
    dplyr::filter(!is.na(.data$pollster_name)) |>
    dplyr::select(-pollster_name)
}

empty_house_effects <- function() {
  dplyr::tibble(
    pollster_key = character(),
    party_key = character(),
    house_effect = numeric(),
    se = numeric(),
    ic_low = numeric(),
    ic_high = numeric(),
    n = integer(),
    house_effect_status = character()
  )
}
