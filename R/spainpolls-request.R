configure_spainpolls_api_url <- function() {
  api_url <- env_chr("SPAINPOLLS_API_URL", "")

  if (!nzchar(api_url)) {
    return(invisible(FALSE))
  }

  if (!requireNamespace("spainpolls", quietly = TRUE)) {
    return(invisible(FALSE))
  }

  spainpolls::set_spainpolls_api_url(api_url)
  invisible(TRUE)
}

configure_spainpolls_ci_request <- function() {
  token <- env_chr("SPAINPOLLS_CI_BYPASS_TOKEN", "")
  user_agent <- env_chr("SPAINPOLLS_USER_AGENT", "")

  if (!nzchar(token) && !nzchar(user_agent)) {
    return(invisible(FALSE))
  }

  if (!requireNamespace("spainpolls", quietly = TRUE)) {
    return(invisible(FALSE))
  }
  if (!requireNamespace("httr2", quietly = TRUE)) {
    stop("Package 'httr2' is required to configure spainpolls CI requests.", call. = FALSE)
  }

  options(spainpolls.request_fn = function(path, query = list()) {
    spainpolls_ci_request(path, query = query, token = token, user_agent = user_agent)
  })

  invisible(TRUE)
}

spainpolls_ci_request <- function(path, query = list(), token = "", user_agent = "") {
  ns <- asNamespace("spainpolls")

  base_url <- get("spainpolls_api_url", ns)()
  url <- get("spainpolls_build_url", ns)(base_url, path)
  query <- get("clean_query", ns)(query)
  timeout_seconds <- get("default_timeout_seconds", ns)

  if (!nzchar(user_agent)) {
    user_agent <- get("spainpolls_user_agent", ns)()
  }

  req <- httr2::request(url) |>
    httr2::req_timeout(timeout_seconds) |>
    httr2::req_user_agent(user_agent) |>
    httr2::req_headers(Accept = "application/json") |>
    httr2::req_error(is_error = function(resp) FALSE)

  if (nzchar(token)) {
    req <- httr2::req_headers(req, "X-SpainPolls-CI-Token" = token)
  }

  if (length(query) > 0) {
    req <- do.call(httr2::req_url_query, c(list(req), query, list(.multi = "explode")))
  }

  resp <- tryCatch(
    httr2::req_perform(req),
    error = function(cnd) {
      cli::cli_abort(
        "Could not connect to Spain Electoral Polls API at {.url {base_url}}.",
        parent = cnd
      )
    }
  )

  status <- httr2::resp_status(resp)
  if (status >= 400) {
    headers <- httr2::resp_headers(resp)
    cf_ray <- headers[["cf-ray"]] %||% "<missing>"
    server <- headers[["server"]] %||% "<missing>"
    body <- tryCatch(
      httr2::resp_body_string(resp),
      error = function(cnd) ""
    )
    body <- gsub("[\r\n\t]+", " ", body)
    body <- substr(body, 1, 500)

    cli::cli_abort(c(
      "Spain Electoral Polls API rejected the CI request.",
      "i" = "HTTP status: {status}",
      "i" = "Server: {server}",
      "i" = "CF-Ray: {cf_ray}",
      "i" = "Response preview: {body}"
    ))
  }

  get("parse_json_response", ns)(resp)
}
