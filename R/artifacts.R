build_poll_artifacts <- function(config = default_config()) {
  average_ts <- fetch_poll_timeseries(
    election_key = config$average_election_key,
    party_key = config$parties,
    date_field = config$date_field,
    include_manual_review = FALSE,
    filter_overlapping_fieldwork = config$filter_overlapping_fieldwork
  )

  house_ts <- fetch_poll_timeseries(
    election_key = config$house_effect_election_keys,
    party_key = config$parties,
    date_field = config$date_field,
    include_manual_review = FALSE,
    filter_overlapping_fieldwork = config$filter_overlapping_fieldwork
  )

  public_tables <- build_public_poll_tables(average_ts)
  poll_average_daily <- build_poll_average_daily(public_tables$poll_results)
  poll_deviations <- build_poll_deviations(
    public_tables$poll_results,
    poll_average_daily
  )
  house_effects <- fit_house_effects(
    house_ts,
    min_polls_pollster_party = config$min_polls_pollster_party
  )

  artifacts <- list(
    polls = public_tables$polls,
    poll_results = public_tables$poll_results |>
      dplyr::select(-dplyr::any_of("sample_size_weight")),
    poll_average_daily = poll_average_daily,
    poll_deviations = poll_deviations |>
      dplyr::select(-dplyr::any_of("sample_size_weight")),
    house_effects = house_effects
  )
  artifacts$manifest <- build_manifest(artifacts, config)

  artifacts
}

build_manifest <- function(artifacts, config = default_config(), run_id = NULL) {
  polls <- artifacts$polls
  poll_results <- artifacts$poll_results
  house_effects <- artifacts$house_effects
  latest_fieldwork_end <- suppressWarnings(max(polls$fieldwork_end, na.rm = TRUE))

  if (!is.finite(latest_fieldwork_end)) {
    latest_fieldwork_end <- NA
  }

  list(
    schema_version = "1.0.0",
    project_version = project_version(),
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    run_id = run_id %||% format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"),
    source = "spainpolls",
    average_election_key = config$average_election_key,
    house_effect_election_keys = config$house_effect_election_keys,
    parties = config$parties,
    filter_overlapping_fieldwork = config$filter_overlapping_fieldwork,
    latest_fieldwork_end = as.character(latest_fieldwork_end),
    row_counts = list(
      polls = nrow(polls),
      poll_results = nrow(poll_results),
      poll_average_daily = nrow(artifacts$poll_average_daily),
      poll_deviations = nrow(artifacts$poll_deviations),
      house_effects = nrow(house_effects)
    ),
    validation_status = artifacts$validation_status %||% "not_run"
  )
}
