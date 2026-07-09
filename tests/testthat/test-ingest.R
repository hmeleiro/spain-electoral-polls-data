test_that("non_overlapping_poll_ids keeps the newest non-overlapping polls", {
  polls <- tibble::tibble(
    id = c("older_overlap", "latest", "older_clear", "other_pollster"),
    election_key = "congreso_espana_2027",
    pollster_key = c("demo", "demo", "demo", "other"),
    fieldwork_start = as.Date(c(
      "2026-07-03",
      "2026-07-05",
      "2026-06-29",
      "2026-07-03"
    )),
    fieldwork_end = as.Date(c(
      "2026-07-07",
      "2026-07-09",
      "2026-07-02",
      "2026-07-07"
    )),
    publication_date = as.Date(c(
      "2026-07-07",
      "2026-07-09",
      "2026-07-02",
      "2026-07-07"
    ))
  )

  out <- non_overlapping_poll_ids(polls)

  expect_setequal(
    out$poll_id,
    c("latest", "older_clear", "other_pollster")
  )
  expect_false("older_overlap" %in% out$poll_id)
})

test_that("filter_poll_timeseries_overlapping_fieldwork filters by poll_id", {
  ts <- tibble::tibble(
    poll_id = c("older_overlap", "older_overlap", "latest"),
    election_key = "congreso_espana_2027",
    party_key = c("psoe", "pp", "psoe"),
    vote_share = c(30, 34, 31)
  )
  polls <- tibble::tibble(
    poll_id = c("older_overlap", "latest"),
    election_key = "congreso_espana_2027",
    pollster_key = "demo",
    fieldwork_start = as.Date(c("2026-07-03", "2026-07-05")),
    fieldwork_end = as.Date(c("2026-07-07", "2026-07-09")),
    publication_date = as.Date(c("2026-07-07", "2026-07-09"))
  )

  out <- filter_poll_timeseries_overlapping_fieldwork(ts, polls)

  expect_equal(out$poll_id, "latest")
  expect_equal(out$party_key, "psoe")
})

test_that("enrich_poll_timeseries_metadata fills dates from poll metadata", {
  ts <- tibble::tibble(
    poll_id = 1L,
    election_key = "congreso_espana_2027",
    date = as.Date("2026-07-09"),
    party_key = "psoe",
    vote_share = 30
  )
  polls <- tibble::tibble(
    id = 1L,
    election_key = "congreso_espana_2027",
    fieldwork_start = as.Date("2026-07-05"),
    fieldwork_end = as.Date("2026-07-09"),
    publication_date = as.Date("2026-07-10"),
    source_url = "https://example.test/poll"
  )

  out <- enrich_poll_timeseries_metadata(ts, polls)

  expect_equal(out$poll_id, "1")
  expect_equal(out$fieldwork_start, as.Date("2026-07-05"))
  expect_equal(out$fieldwork_end, as.Date("2026-07-09"))
  expect_equal(out$publication_date, as.Date("2026-07-10"))
  expect_equal(out$source_url, "https://example.test/poll")
})

test_that("non_overlapping_poll_ids keeps polls with incomplete fieldwork dates", {
  polls <- tibble::tibble(
    poll_id = c("unknown", "dated"),
    election_key = "congreso_espana_2027",
    pollster_key = "demo",
    fieldwork_start = as.Date(c(NA, "2026-07-05")),
    fieldwork_end = as.Date(c(NA, "2026-07-09")),
    publication_date = as.Date(c("2026-07-01", "2026-07-09"))
  )

  out <- non_overlapping_poll_ids(polls)

  expect_setequal(out$poll_id, c("unknown", "dated"))
})
