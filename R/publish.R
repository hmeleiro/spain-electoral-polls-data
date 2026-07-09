publish_artifacts_to_r2 <- function(
  artifact_dir = "artifacts",
  bucket = Sys.getenv("R2_BUCKET"),
  prefix = Sys.getenv("R2_PREFIX", "spain-electoral-polls"),
  endpoint = Sys.getenv("AWS_S3_ENDPOINT")
) {
  if (!requireNamespace("aws.s3", quietly = TRUE)) {
    stop("Package 'aws.s3' is required to publish to R2.", call. = FALSE)
  }
  if (!requireNamespace("aws.signature", quietly = TRUE)) {
    stop("Package 'aws.signature' is required to sign R2 requests.", call. = FALSE)
  }
  if (!requireNamespace("httr", quietly = TRUE)) {
    stop("Package 'httr' is required to publish to R2.", call. = FALSE)
  }
  if (!nzchar(bucket)) {
    stop("R2_BUCKET is required.", call. = FALSE)
  }
  if (!nzchar(endpoint)) {
    stop("AWS_S3_ENDPOINT is required.", call. = FALSE)
  }

  endpoint <- normalize_r2_endpoint(endpoint)
  signing_region <- Sys.getenv("AWS_DEFAULT_REGION", "auto")
  Sys.setenv(AWS_DEFAULT_REGION = signing_region)

  files <- list_latest_artifact_files(artifact_dir)
  if (length(files) == 0) {
    stop("No latest artifact files found under ", file.path(artifact_dir, "latest"), call. = FALSE)
  }

  uploaded <- lapply(files, function(path) {
    rel <- normalizePath(path, winslash = "/", mustWork = TRUE)
    root <- normalizePath(artifact_dir, winslash = "/", mustWork = TRUE)
    object <- sub(paste0("^", root, "/?"), "", rel)
    object <- paste(trimws(prefix, whitespace = "/"), object, sep = "/")

    put_r2_object(
      file = path,
      bucket = bucket,
      object = object,
      endpoint = endpoint,
      region = signing_region
    )

    object
  })

  unlist(uploaded, use.names = FALSE)
}

list_latest_artifact_files <- function(artifact_dir = "artifacts") {
  latest_dir <- file.path(artifact_dir, "latest")
  files <- list.files(latest_dir, recursive = TRUE, full.names = TRUE)
  files[file.info(files)$isdir == FALSE]
}

put_r2_object <- function(file, bucket, object, endpoint, region = "auto") {
  action <- encode_s3_path(c(bucket, strsplit(object, "/", fixed = TRUE)[[1]]))
  url <- paste0("https://", endpoint, action)
  timestamp <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")

  canonical_headers <- list(
    host = endpoint,
    `x-amz-date` = timestamp
  )

  sig <- aws.signature::signature_v4_auth(
    datetime = timestamp,
    region = region,
    service = "s3",
    verb = "PUT",
    action = action,
    canonical_headers = canonical_headers,
    request_body = file,
    signed_body = TRUE
  )

  body <- readBin(file, what = "raw", n = file.info(file)$size)
  headers <- httr::add_headers(
    Authorization = sig$SignatureHeader,
    `x-amz-date` = timestamp,
    `x-amz-content-sha256` = sig$BodyHash
  )

  response <- httr::PUT(url, headers, body = body)
  if (httr::http_error(response)) {
    stop(
      "R2 upload failed for ",
      object,
      ": HTTP ",
      httr::status_code(response),
      " ",
      httr::content(response, as = "text", encoding = "UTF-8"),
      call. = FALSE
    )
  }

  invisible(TRUE)
}

encode_s3_path <- function(parts) {
  parts <- parts[nzchar(parts)]
  paste0("/", paste(vapply(parts, URLencode, character(1), reserved = TRUE), collapse = "/"))
}

normalize_r2_endpoint <- function(endpoint) {
  endpoint <- trimws(endpoint)
  endpoint <- sub("^https?://", "", endpoint, ignore.case = TRUE)
  endpoint <- sub("/+$", "", endpoint)

  if (grepl("/", endpoint, fixed = TRUE)) {
    stop(
      "AWS_S3_ENDPOINT must be only the R2 host, without path. ",
      "Example: <account_id>.r2.cloudflarestorage.com",
      call. = FALSE
    )
  }

  if (grepl("^auto[.]", endpoint, ignore.case = TRUE)) {
    stop(
      "AWS_S3_ENDPOINT appears to include the region prefix 'auto.'. ",
      "For Cloudflare R2 use AWS_DEFAULT_REGION=auto and ",
      "AWS_S3_ENDPOINT=<account_id>.r2.cloudflarestorage.com.",
      call. = FALSE
    )
  }

  endpoint
}
