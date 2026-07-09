restore_env <- function(name, value) {
  if (is.na(value)) {
    Sys.unsetenv(name)
  } else {
    do.call(Sys.setenv, as.list(stats::setNames(value, name)))
  }
}

test_that("configure_spainpolls_ci_request is opt-in", {
  old_token <- Sys.getenv("SPAINPOLLS_CI_BYPASS_TOKEN", unset = NA_character_)
  old_user_agent <- Sys.getenv("SPAINPOLLS_USER_AGENT", unset = NA_character_)
  old_request_fn <- getOption("spainpolls.request_fn")
  on.exit({
    restore_env("SPAINPOLLS_CI_BYPASS_TOKEN", old_token)
    restore_env("SPAINPOLLS_USER_AGENT", old_user_agent)
    options(spainpolls.request_fn = old_request_fn)
  }, add = TRUE)

  Sys.unsetenv(c("SPAINPOLLS_CI_BYPASS_TOKEN", "SPAINPOLLS_USER_AGENT"))
  options(spainpolls.request_fn = NULL)

  expect_false(configure_spainpolls_ci_request())
  expect_null(getOption("spainpolls.request_fn"))
})

test_that("configure_spainpolls_ci_request registers request override with token", {
  old_token <- Sys.getenv("SPAINPOLLS_CI_BYPASS_TOKEN", unset = NA_character_)
  old_user_agent <- Sys.getenv("SPAINPOLLS_USER_AGENT", unset = NA_character_)
  old_request_fn <- getOption("spainpolls.request_fn")
  on.exit({
    restore_env("SPAINPOLLS_CI_BYPASS_TOKEN", old_token)
    restore_env("SPAINPOLLS_USER_AGENT", old_user_agent)
    options(spainpolls.request_fn = old_request_fn)
  }, add = TRUE)

  Sys.setenv(SPAINPOLLS_CI_BYPASS_TOKEN = "dummy")
  Sys.unsetenv("SPAINPOLLS_USER_AGENT")
  options(spainpolls.request_fn = NULL)

  expect_true(configure_spainpolls_ci_request())
  expect_true(is.function(getOption("spainpolls.request_fn")))
})
