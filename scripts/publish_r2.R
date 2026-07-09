source("R/utils.R")
load_env_file(".env", quiet = TRUE)
source_project_files("R")

artifact_dir <- Sys.getenv("ARTIFACT_DIR", unset = "artifacts")
uploaded <- publish_artifacts_to_r2(artifact_dir = artifact_dir)

message("Uploaded ", length(uploaded), " files to R2.")
