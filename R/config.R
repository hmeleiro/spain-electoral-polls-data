default_config <- function() {
  list(
    average_election_key = "congreso_espana_2027",
    house_effect_election_keys = c("congreso_espana_2027", "congreso_espana_2023"),
    parties = c("psoe", "pp", "vox", "sumar", "podemos", "salf"),
    date_field = "fieldwork_end",
    filter_overlapping_fieldwork = TRUE,
    min_polls_pollster_party = 5L,
    output_dir = "artifacts",
    freshness_days = 45L
  )
}

config_from_env <- function() {
  config <- default_config()

  config$average_election_key <- env_chr(
    "AVERAGE_ELECTION_KEY",
    config$average_election_key
  )
  config$house_effect_election_keys <- env_chr_vec(
    "HOUSE_EFFECT_ELECTION_KEYS",
    config$house_effect_election_keys
  )
  config$parties <- env_chr_vec("PARTIES", config$parties)
  config$date_field <- env_chr("DATE_FIELD", config$date_field)
  config$filter_overlapping_fieldwork <- env_lgl(
    "FILTER_OVERLAPPING_FIELDWORK",
    config$filter_overlapping_fieldwork
  )
  config$min_polls_pollster_party <- env_int(
    "MIN_POLLS_POLLSTER_PARTY",
    config$min_polls_pollster_party
  )
  config$output_dir <- env_chr("ARTIFACT_DIR", config$output_dir)
  config$freshness_days <- env_int("FRESHNESS_DAYS", config$freshness_days)

  config
}

env_chr <- function(name, default) {
  value <- Sys.getenv(name, unset = NA_character_)
  if (is.na(value) || !nzchar(value)) {
    return(default)
  }
  value
}

env_int <- function(name, default) {
  value <- Sys.getenv(name, unset = NA_character_)
  if (is.na(value) || !nzchar(value)) {
    return(default)
  }
  as.integer(value)
}

env_lgl <- function(name, default) {
  value <- Sys.getenv(name, unset = NA_character_)
  if (is.na(value) || !nzchar(value)) {
    return(default)
  }

  normalized <- tolower(trimws(value))
  if (normalized %in% c("true", "t", "1", "yes", "y")) {
    return(TRUE)
  }
  if (normalized %in% c("false", "f", "0", "no", "n")) {
    return(FALSE)
  }

  stop("Environment variable ", name, " must be true or false.", call. = FALSE)
}

env_chr_vec <- function(name, default) {
  value <- Sys.getenv(name, unset = NA_character_)
  if (is.na(value) || !nzchar(value)) {
    return(default)
  }
  trimws(strsplit(value, ",", fixed = TRUE)[[1]])
}
