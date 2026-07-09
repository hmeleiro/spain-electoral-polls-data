source("R/utils.R")
load_env_file(".env", quiet = TRUE)
source_project_files("R")

config <- config_from_env()
run_id <- Sys.getenv(
  "RUN_ID",
  unset = format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
)

artifacts <- build_poll_artifacts(config)
validation <- validate_public_artifacts(
  artifacts,
  current_date = Sys.Date(),
  freshness_days = config$freshness_days
)

write_artifacts(
  artifacts,
  output_dir = config$output_dir,
  run_id = run_id,
  validation_report = validation
)

assert_validation_ok(validation)

message("Artifacts written to ", config$output_dir, " with run_id=", run_id)
