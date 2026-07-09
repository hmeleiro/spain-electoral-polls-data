kalman_daily <- function(df) {
  required_cols <- c("date", "vote_share")
  missing_cols <- setdiff(required_cols, names(df))

  if (length(missing_cols) > 0) {
    stop(
      "Missing required columns: ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
  }

  if (!"sample_size_weight" %in% names(df)) {
    df$sample_size_weight <- 1
  }

  df <- df |>
    dplyr::mutate(
      date = as.Date(.data$date),
      vote_share = as.numeric(.data$vote_share),
      sample_size_weight = as.numeric(.data$sample_size_weight)
    ) |>
    dplyr::filter(
      !is.na(.data$date),
      !is.na(.data$vote_share)
    )

  if (nrow(df) < 3) {
    sparse <- df |>
      dplyr::count(.data$date, name = "n_polls_day") |>
      dplyr::arrange(.data$date)

    return(dplyr::tibble(
      date = sparse$date,
      average_vote_share = NA_real_,
      n_polls_day = sparse$n_polls_day
    ))
  }

  daily_observed <- df |>
    dplyr::group_by(.data$date) |>
    dplyr::summarise(
      vote_share = weighted_mean_or_mean(
        .data$vote_share,
        .data$sample_size_weight
      ),
      n_polls_day = dplyr::n(),
      .groups = "drop"
    )

  df_daily <- daily_observed |>
    tidyr::complete(
      date = seq(
        min(.data$date),
        max(.data$date),
        by = "day"
      )
    ) |>
    dplyr::arrange(.data$date)

  y <- df_daily$vote_share
  init_var <- var(y, na.rm = TRUE)

  if (is.na(init_var) || !is.finite(init_var) || init_var <= 0) {
    init_var <- 1
  }

  SSMtrend <- KFAS::SSMtrend
  model <- KFAS::SSModel(
    y ~ SSMtrend(
      degree = 1,
      Q = NA
    ),
    H = NA
  )

  fit <- KFAS::fitSSM(
    model,
    inits = log(
      c(
        init_var * 0.01,
        init_var * 0.50
      )
    ),
    method = "BFGS"
  )

  kfs <- KFAS::KFS(
    fit$model,
    smoothing = "state"
  )

  df_daily |>
    dplyr::transmute(
      date = .data$date,
      average_vote_share = drop(kfs$alphahat[, 1]),
      n_polls_day = tidyr::replace_na(.data$n_polls_day, 0L)
    )
}

build_poll_average_daily <- function(ts) {
  required_cols <- c("election_key", "party_key", "date", "vote_share")
  assert_columns(ts, required_cols, "poll timeseries")

  ts |>
    dplyr::group_by(.data$election_key, .data$party_key) |>
    dplyr::group_modify(\(df, key) kalman_daily(df)) |>
    dplyr::ungroup()
}

build_poll_deviations <- function(poll_results, poll_average_daily) {
  required_results <- c("poll_id", "election_key", "party_key", "date", "vote_share")
  required_average <- c("election_key", "party_key", "date", "average_vote_share")
  assert_columns(poll_results, required_results, "poll results")
  assert_columns(poll_average_daily, required_average, "poll average")

  poll_results |>
    dplyr::left_join(
      poll_average_daily |>
        dplyr::select(dplyr::all_of(c(
          "election_key",
          "party_key",
          "date",
          "average_vote_share"
        ))),
      by = c("election_key", "party_key", "date")
    ) |>
    dplyr::mutate(
      deviation_from_average = .data$vote_share - .data$average_vote_share
    )
}
