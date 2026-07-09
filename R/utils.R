`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

assert_columns <- function(df, required_cols, label = "data frame") {
  missing_cols <- setdiff(required_cols, names(df))
  if (length(missing_cols) > 0) {
    stop(
      label,
      " is missing required columns: ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

add_missing_columns <- function(df, cols, value = NA) {
  for (col in cols) {
    if (!col %in% names(df)) {
      df[[col]] <- value
    }
  }
  df
}

weighted_mean_or_mean <- function(x, w = NULL) {
  valid <- !is.na(x)
  if (!any(valid)) {
    return(NA_real_)
  }

  x <- x[valid]
  if (is.null(w)) {
    return(mean(x, na.rm = TRUE))
  }

  w <- w[valid]
  valid_weight <- !is.na(w) & is.finite(w) & w > 0
  if (!any(valid_weight)) {
    return(mean(x, na.rm = TRUE))
  }

  stats::weighted.mean(x[valid_weight], w[valid_weight], na.rm = TRUE)
}

project_version <- function() {
  desc <- file.path(getwd(), "DESCRIPTION")
  if (!file.exists(desc)) {
    return(NA_character_)
  }
  dcf <- read.dcf(desc)
  unname(dcf[1, "Version"])
}

source_project_files <- function(path = "R") {
  files <- sort(list.files(path, pattern = "[.]R$", full.names = TRUE))
  for (file in files) {
    source(file)
  }
  invisible(files)
}

load_env_file <- function(path = ".env", quiet = FALSE) {
  if (!file.exists(path)) {
    if (!quiet) {
      message("No .env file found at ", path, "; using current environment.")
    }
    return(invisible(FALSE))
  }

  readRenviron(path)
  if (!quiet) {
    message("Loaded environment from ", path)
  }
  invisible(TRUE)
}
