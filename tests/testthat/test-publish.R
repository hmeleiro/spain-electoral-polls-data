test_that("normalize_r2_endpoint accepts Cloudflare R2 host formats", {
  expect_equal(
    normalize_r2_endpoint("https://abc123.r2.cloudflarestorage.com/"),
    "abc123.r2.cloudflarestorage.com"
  )
})

test_that("normalize_r2_endpoint rejects region-prefixed endpoint", {
  expect_error(
    normalize_r2_endpoint("auto.abc123.r2.cloudflarestorage.com"),
    "region prefix"
  )
})

test_that("encode_s3_path preserves path-style bucket and object slashes", {
  expect_equal(
    encode_s3_path(c("bucket-name", "spain-electoral-polls", "latest", "manifest.json")),
    "/bucket-name/spain-electoral-polls/latest/manifest.json"
  )
})

test_that("R2 publication only selects latest artifacts", {
  artifact_dir <- tempfile("artifacts-")
  on.exit(unlink(artifact_dir, recursive = TRUE), add = TRUE)
  dir.create(file.path(artifact_dir, "latest"), recursive = TRUE)
  dir.create(file.path(artifact_dir, "runs", "20260709T120000Z"), recursive = TRUE)
  writeLines("{}", file.path(artifact_dir, "latest", "manifest.json"))
  writeLines("{}", file.path(artifact_dir, "runs", "20260709T120000Z", "manifest.json"))

  files <- normalizePath(list_latest_artifact_files(artifact_dir), winslash = "/")

  expect_length(files, 1)
  expect_match(files, "/latest/manifest[.]json$")
  expect_false(any(grepl("/runs/", files, fixed = TRUE)))
})
