`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

api_url <- Sys.getenv(
  "SPAINPOLLS_API_URL",
  unset = "https://pollsdb.spainelectoralproject.com"
)
api_url <- sub("/+$", "", api_url)
url <- paste0(api_url, "/api/v1/polls")

token <- Sys.getenv("SPAINPOLLS_CI_BYPASS_TOKEN", unset = "")
user_agent <- Sys.getenv(
  "SPAINPOLLS_USER_AGENT",
  unset = "spainpolls R package/ci-preflight"
)

req <- httr2::request(url) |>
  httr2::req_timeout(30) |>
  httr2::req_user_agent(user_agent) |>
  httr2::req_headers(Accept = "application/json") |>
  httr2::req_url_query(limit = 1, offset = 0) |>
  httr2::req_error(is_error = function(resp) FALSE)

if (nzchar(token)) {
  req <- httr2::req_headers(req, "X-SpainPolls-CI-Token" = token)
}

message("Checking SpainPolls API access at ", url)
message("CI bypass token configured: ", if (nzchar(token)) "yes" else "no")

resp <- tryCatch(
  httr2::req_perform(req),
  error = function(cnd) {
    message("Request failed before receiving an HTTP response: ", conditionMessage(cnd))
    quit(status = 1, save = "no")
  }
)

headers <- httr2::resp_headers(resp)
status <- httr2::resp_status(resp)

message("HTTP status: ", status)
message("Server: ", headers[["server"]] %||% "<missing>")
message("CF-Ray: ", headers[["cf-ray"]] %||% "<missing>")
message("CF-Cache-Status: ", headers[["cf-cache-status"]] %||% "<missing>")
message("Content-Type: ", headers[["content-type"]] %||% "<missing>")

if (status >= 400) {
  body <- tryCatch(
    httr2::resp_body_string(resp),
    error = function(cnd) ""
  )
  body <- gsub("[\r\n\t]+", " ", body)
  message("Response preview: ", substr(body, 1, 1000))
  quit(status = 1, save = "no")
}

message("SpainPolls API preflight passed.")
