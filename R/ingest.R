fetch_poll_timeseries <- function(
  election_key,
  party_key,
  date_field = "fieldwork_end",
  include_manual_review = FALSE,
  collect_all = TRUE,
  filter_overlapping_fieldwork = TRUE
) {
  if (!requireNamespace("spainpolls", quietly = TRUE)) {
    stop("Package 'spainpolls' is required to fetch poll data.", call. = FALSE)
  }

  polls <- fetch_poll_metadata(
    election_key = election_key,
    include_manual_review = include_manual_review,
    collect_all = collect_all
  )

  ts <- lapply(election_key, function(key) {
    spainpolls::get_timeseries(
      election_key = key,
      date_field = date_field,
      party_key = party_key,
      collect_all = collect_all,
      include_manual_review = include_manual_review
    ) |>
      dplyr::mutate(election_key = key)
  }) |>
    dplyr::bind_rows()

  ts <- enrich_poll_timeseries_metadata(ts, polls)

  if (isTRUE(filter_overlapping_fieldwork)) {
    ts <- filter_poll_timeseries_overlapping_fieldwork(ts, polls)
  }

  normalize_poll_timeseries(ts, date_field = date_field)
}

fetch_poll_metadata <- function(
  election_key,
  include_manual_review = FALSE,
  collect_all = TRUE
) {
  lapply(election_key, function(key) {
    spainpolls::get_polls(
      election_key = key,
      include_manual_review = include_manual_review,
      collect_all = collect_all
    ) |>
      normalize_poll_metadata_ids() |>
      dplyr::mutate(election_key = key)
  }) |>
    dplyr::bind_rows()
}

normalize_poll_metadata_ids <- function(polls) {
  if (!"poll_id" %in% names(polls) && "id" %in% names(polls)) {
    polls <- dplyr::rename(polls, poll_id = "id")
  }

  polls
}

enrich_poll_timeseries_metadata <- function(ts, polls) {
  if (is.null(polls) || nrow(polls) == 0) {
    return(ts)
  }

  polls <- normalize_poll_metadata_ids(polls)
  assert_columns(ts, c("poll_id"), "poll timeseries")
  assert_columns(polls, c("poll_id"), "poll metadata")

  join_cols <- intersect(c("poll_id", "election_key"), names(ts))
  join_cols <- intersect(join_cols, names(polls))

  if (length(join_cols) == 0) {
    return(ts)
  }

  metadata_cols <- intersect(
    c(
      join_cols,
      "pollster_key", "pollster_name", "media", "fieldwork_start",
      "fieldwork_end", "publication_date", "sample_size",
      "identity_status", "source_url", "source_title"
    ),
    names(polls)
  )
  metadata_cols <- unique(metadata_cols)
  value_cols <- setdiff(metadata_cols, join_cols)

  if (length(value_cols) == 0) {
    return(ts)
  }

  metadata <- polls |>
    dplyr::select(dplyr::all_of(metadata_cols)) |>
    dplyr::distinct() |>
    dplyr::mutate(
      dplyr::across(dplyr::all_of(join_cols), as.character)
    )

  ts |>
    dplyr::mutate(
      dplyr::across(dplyr::all_of(join_cols), as.character)
    ) |>
    dplyr::left_join(metadata, by = join_cols, suffix = c("", "_metadata")) |>
    coalesce_metadata_columns(value_cols)
}

coalesce_metadata_columns <- function(ts, cols) {
  for (col in cols) {
    metadata_col <- paste0(col, "_metadata")
    if (!metadata_col %in% names(ts)) {
      next
    }

    if (col %in% names(ts)) {
      ts[[col]] <- dplyr::coalesce(ts[[col]], ts[[metadata_col]])
    } else {
      ts[[col]] <- ts[[metadata_col]]
    }
    ts[[metadata_col]] <- NULL
  }

  ts
}

filter_poll_timeseries_overlapping_fieldwork <- function(ts, polls) {
  assert_columns(ts, c("poll_id"), "poll timeseries")

  if (is.null(polls) || nrow(polls) == 0) {
    return(ts)
  }

  kept_poll_ids <- non_overlapping_poll_ids(polls)
  join_cols <- intersect(c("poll_id", "election_key"), names(ts))
  join_cols <- intersect(join_cols, names(kept_poll_ids))

  if (length(join_cols) == 0) {
    return(ts)
  }

  ts <- ts |>
    dplyr::mutate(
      dplyr::across(dplyr::all_of(join_cols), as.character)
    )

  dplyr::semi_join(ts, kept_poll_ids, by = join_cols)
}

non_overlapping_poll_ids <- function(polls) {
  polls <- normalize_poll_metadata_ids(polls)

  required <- c("poll_id", "pollster_key", "fieldwork_start", "fieldwork_end")
  assert_columns(polls, required, "poll metadata")

  optional <- c("election_key", "publication_date")
  polls <- add_missing_columns(polls, optional)

  polls |>
    dplyr::transmute(
      poll_id = as.character(.data$poll_id),
      election_key = as.character(.data$election_key),
      pollster_key = as.character(.data$pollster_key),
      fieldwork_start = as.Date(.data$fieldwork_start),
      fieldwork_end = as.Date(.data$fieldwork_end),
      publication_date = as.Date(.data$publication_date)
    ) |>
    dplyr::distinct() |>
    dplyr::group_by(.data$election_key, .data$pollster_key) |>
    dplyr::group_modify(\(df, key) keep_non_overlapping_fieldwork(df)) |>
    dplyr::ungroup() |>
    dplyr::select(dplyr::all_of(c("poll_id", "election_key")))
}

keep_non_overlapping_fieldwork <- function(df) {
  df <- df |>
    dplyr::arrange(
      dplyr::desc(.data$fieldwork_end),
      dplyr::desc(.data$publication_date),
      dplyr::desc(.data$fieldwork_start),
      dplyr::desc(.data$poll_id)
    )

  keep <- rep(FALSE, nrow(df))
  kept_start <- as.Date(character())
  kept_end <- as.Date(character())

  for (i in seq_len(nrow(df))) {
    start <- df$fieldwork_start[i]
    end <- df$fieldwork_end[i]

    if (is.na(start)) {
      start <- end
    }
    if (is.na(end)) {
      end <- start
    }

    if (is.na(start) || is.na(end)) {
      keep[i] <- TRUE
      next
    }

    overlaps <- length(kept_start) > 0 &&
      any(start <= kept_end & end >= kept_start)

    if (!overlaps) {
      keep[i] <- TRUE
      kept_start <- c(kept_start, start)
      kept_end <- c(kept_end, end)
    }
  }

  df[keep, , drop = FALSE]
}

normalize_poll_timeseries <- function(ts, date_field = "fieldwork_end") {
  required <- c("poll_id", "election_key", "party_key", "vote_share")
  assert_columns(ts, required, "poll timeseries")

  optional <- c(
    "pollster_key", "pollster_name", "media", "fieldwork_start",
    "fieldwork_end", "publication_date", "sample_size", "party_name",
    "short_name", "color_hex", "identity_status", "source_url",
    "source_title", "date"
  )

  ts <- add_missing_columns(ts, optional)

  if (all(is.na(ts$date))) {
    if (!date_field %in% names(ts)) {
      stop("date_field '", date_field, "' is not available.", call. = FALSE)
    }
    ts$date <- ts[[date_field]]
  }

  if (all(is.na(ts$fieldwork_end))) {
    ts$fieldwork_end <- ts$date
  }

  ts |>
    dplyr::mutate(
      poll_id = as.character(.data$poll_id),
      election_key = as.character(.data$election_key),
      pollster_key = as.character(.data$pollster_key),
      pollster_name = as.character(.data$pollster_name),
      media = as.character(.data$media),
      party_key = as.character(.data$party_key),
      party_name = as.character(.data$party_name),
      short_name = as.character(.data$short_name),
      color_hex = as.character(.data$color_hex),
      identity_status = as.character(.data$identity_status),
      source_url = as.character(.data$source_url),
      source_title = as.character(.data$source_title),
      date = as.Date(.data$date),
      fieldwork_start = as.Date(.data$fieldwork_start),
      fieldwork_end = as.Date(.data$fieldwork_end),
      publication_date = as.Date(.data$publication_date),
      vote_share = as.numeric(.data$vote_share),
      sample_size = as.numeric(.data$sample_size)
    ) |>
    add_sample_size_weights()
}

add_sample_size_weights <- function(ts) {
  assert_columns(ts, c("poll_id", "sample_size"), "poll timeseries")

  sample_sizes <- ts |>
    dplyr::select(dplyr::all_of(c("poll_id", "sample_size"))) |>
    dplyr::distinct() |>
    dplyr::mutate(sample_size_original = .data$sample_size)

  fallback <- mean(sample_sizes$sample_size, na.rm = TRUE)
  if (is.na(fallback) || !is.finite(fallback) || fallback <= 0) {
    fallback <- 1
  }

  sample_sizes <- sample_sizes |>
    dplyr::mutate(
      sample_size_imputed = is.na(.data$sample_size) | .data$sample_size <= 0,
      sample_size_weight = dplyr::if_else(
        .data$sample_size_imputed,
        fallback,
        .data$sample_size
      )
    ) |>
    dplyr::select(dplyr::all_of(c(
      "poll_id",
      "sample_size_original",
      "sample_size_imputed",
      "sample_size_weight"
    )))

  ts |>
    dplyr::select(-dplyr::any_of(c(
      "sample_size_original",
      "sample_size_imputed",
      "sample_size_weight"
    ))) |>
    dplyr::left_join(sample_sizes, by = "poll_id")
}

build_public_poll_tables <- function(ts) {
  required <- c(
    "poll_id", "election_key", "pollster_key", "pollster_name", "media",
    "fieldwork_start", "fieldwork_end", "publication_date", "sample_size",
    "sample_size_imputed", "party_key", "party_name", "short_name",
    "color_hex", "vote_share"
  )
  assert_columns(ts, required, "poll timeseries")

  polls <- ts |>
    dplyr::select(dplyr::all_of(c(
      "poll_id",
      "election_key",
      "pollster_key",
      "pollster_name",
      "media",
      "fieldwork_start",
      "fieldwork_end",
      "publication_date",
      "sample_size",
      "sample_size_imputed",
      "source_url",
      "source_title"
    ))) |>
    dplyr::distinct() |>
    dplyr::arrange(
      dplyr::desc(.data$fieldwork_end),
      dplyr::desc(.data$publication_date),
      .data$pollster_name,
      .data$poll_id
    )

  poll_results <- ts |>
    dplyr::select(dplyr::all_of(c(
      "poll_id",
      "election_key",
      "pollster_key",
      "pollster_name",
      "media",
      "fieldwork_start",
      "fieldwork_end",
      "publication_date",
      "date",
      "sample_size",
      "sample_size_imputed",
      "sample_size_weight",
      "party_key",
      "party_name",
      "short_name",
      "color_hex",
      "vote_share"
    ))) |>
    dplyr::arrange(
      .data$poll_id,
      .data$party_key
    )

  list(polls = polls, poll_results = poll_results)
}
