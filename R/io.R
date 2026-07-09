write_artifacts <- function(
  artifacts,
  output_dir = "artifacts",
  run_id = format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"),
  validation_report = NULL
) {
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("Package 'arrow' is required to write parquet files.", call. = FALSE)
  }
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required to write json files.", call. = FALSE)
  }

  latest_dir <- file.path(output_dir, "latest")
  run_dir <- file.path(output_dir, "runs", run_id)
  dir.create(latest_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)

  artifacts$manifest$run_id <- run_id
  artifacts$manifest$validation_status <- validation_report$status %||% "not_run"

  write_artifact_set(artifacts, latest_dir, validation_report)
  write_artifact_set(artifacts, run_dir, validation_report)

  invisible(list(latest_dir = latest_dir, run_dir = run_dir, run_id = run_id))
}

write_artifact_set <- function(artifacts, dir, validation_report = NULL) {
  arrow::write_parquet(artifacts$polls, file.path(dir, "polls.parquet"))
  arrow::write_parquet(artifacts$poll_results, file.path(dir, "poll_results.parquet"))
  arrow::write_parquet(
    artifacts$poll_average_daily,
    file.path(dir, "poll_average_daily.parquet")
  )
  arrow::write_parquet(
    artifacts$poll_deviations,
    file.path(dir, "poll_deviations.parquet")
  )
  arrow::write_parquet(artifacts$house_effects, file.path(dir, "house_effects.parquet"))

  jsonlite::write_json(
    artifacts$manifest,
    file.path(dir, "manifest.json"),
    auto_unbox = TRUE,
    pretty = TRUE,
    null = "null"
  )

  if (!is.null(validation_report)) {
    jsonlite::write_json(
      validation_report,
      file.path(dir, "validation_report.json"),
      auto_unbox = TRUE,
      pretty = TRUE,
      null = "null"
    )
  }
}
