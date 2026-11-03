validate_public_artifacts <- function(
  artifacts,
  election_key = "congreso_espana_2026",
  current_date = Sys.Date(),
  freshness_days = 45L
) {
  checks <- list(
    polls_columns = check_required_columns(
      artifacts$polls,
      c(
        "poll_id", "election_key", "pollster_key", "pollster_name", "media",
        "fieldwork_start", "fieldwork_end", "publication_date", "sample_size",
        "sample_size_imputed"
      ),
      "polls"
    ),
    poll_results_columns = check_required_columns(
      artifacts$poll_results,
      c(
        "poll_id", "election_key", "pollster_key", "pollster_name", "media",
        "fieldwork_start", "fieldwork_end", "publication_date", "sample_size",
        "sample_size_imputed", "party_key", "party_name", "short_name",
        "color_hex", "vote_share"
      ),
      "poll_results"
    ),
    vote_share_range = check_vote_share_range(artifacts$poll_results),
    future_dates = check_future_dates(artifacts$polls, current_date),
    duplicate_poll_results = check_duplicate_poll_results(artifacts$poll_results),
    recent_next_election_poll = check_recent_poll(
      artifacts$polls,
      election_key = election_key,
      current_date = current_date,
      freshness_days = freshness_days
    ),
    manifest_exists = list(
      status = if (is.null(artifacts$manifest)) "fail" else "pass",
      severity = "error",
      message = if (is.null(artifacts$manifest)) {
        "manifest is missing"
      } else {
        "manifest is present"
      }
    )
  )

  status <- if (any(vapply(checks, \(x) x$status == "fail" && x$severity == "error", logical(1)))) {
    "failed"
  } else if (any(vapply(checks, \(x) x$status == "fail", logical(1)))) {
    "warning"
  } else {
    "passed"
  }

  list(
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    status = status,
    checks = checks
  )
}

assert_validation_ok <- function(validation_report) {
  if (identical(validation_report$status, "failed")) {
    failed_checks <- Filter(
      \(x) identical(x$status, "fail") && identical(x$severity, "error"),
      validation_report$checks
    )
    failed <- vapply(
      names(failed_checks),
      \(name) paste0(name, " (", failed_checks[[name]]$message, ")"),
      character(1)
    )
    stop(
      "Artifact validation failed: ",
      paste(failed, collapse = ", "),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

check_required_columns <- function(df, cols, label) {
  missing_cols <- setdiff(cols, names(df))
  list(
    status = if (length(missing_cols) == 0) "pass" else "fail",
    severity = "error",
    message = if (length(missing_cols) == 0) {
      paste(label, "has required columns")
    } else {
      paste(label, "is missing columns:", paste(missing_cols, collapse = ", "))
    }
  )
}

check_vote_share_range <- function(poll_results) {
  bad <- poll_results |>
    dplyr::filter(
      !is.na(.data$vote_share),
      .data$vote_share < 0 | .data$vote_share > 100
    )
  list(
    status = if (nrow(bad) == 0) "pass" else "fail",
    severity = "error",
    message = paste(nrow(bad), "vote_share values outside [0, 100]")
  )
}

check_future_dates <- function(polls, current_date) {
  date_cols <- intersect(
    c("fieldwork_start", "fieldwork_end", "publication_date"),
    names(polls)
  )
  future_counts <- vapply(
    date_cols,
    \(col) sum(as.Date(polls[[col]]) > current_date + 1, na.rm = TRUE),
    integer(1)
  )
  total <- sum(future_counts)
  list(
    status = if (total == 0) "pass" else "fail",
    severity = "error",
    message = paste(total, "date values are unexpectedly in the future")
  )
}

check_duplicate_poll_results <- function(poll_results) {
  dupes <- poll_results |>
    dplyr::count(.data$poll_id, .data$party_key, name = "n") |>
    dplyr::filter(.data$n > 1)
  list(
    status = if (nrow(dupes) == 0) "pass" else "fail",
    severity = "error",
    message = paste(nrow(dupes), "duplicate poll_id + party_key rows")
  )
}

check_recent_poll <- function(polls, election_key, current_date, freshness_days) {
  required <- c("election_key", "fieldwork_end")
  missing_cols <- setdiff(required, names(polls))

  if (length(missing_cols) > 0) {
    return(list(
      status = "fail",
      severity = "error",
      message = paste(
        "cannot check poll freshness; polls is missing columns:",
        paste(missing_cols, collapse = ", ")
      )
    ))
  }

  dated_polls <- polls |>
    dplyr::filter(
      .data$election_key == election_key,
      !is.na(.data$fieldwork_end)
    )

  if (nrow(dated_polls) == 0) {
    return(list(
      status = "fail",
      severity = "error",
      message = paste(
        "no polls with a non-missing fieldwork_end for",
        election_key
      )
    ))
  }

  latest <- max(as.Date(dated_polls$fieldwork_end))

  ok <- latest >= current_date - freshness_days

  list(
    status = if (ok) "pass" else "fail",
    severity = "error",
    message = paste(
      "latest",
      election_key,
      "fieldwork_end is",
      as.character(latest),
      "; required on or after",
      as.character(current_date - freshness_days)
    )
  )
}
