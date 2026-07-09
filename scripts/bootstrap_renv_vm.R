Sys.setenv(RENV_CONFIG_CACHE_ENABLED = "FALSE")
source("renv/activate.R")

options(repos = c(CRAN = "https://cloud.r-project.org"))

install_archive <- function(url) {
  lib <- .libPaths()[1]
  dir.create(lib, recursive = TRUE, showWarnings = FALSE)

  utils::install.packages(
    url,
    lib = lib,
    repos = NULL,
    type = "source",
    dependencies = FALSE
  )
}

message("Installing pinned nanonext and mirai versions from CRAN Archive...")
install_archive("https://cran.r-project.org/src/contrib/Archive/nanonext/nanonext_1.8.1.tar.gz")
install_archive("https://cran.r-project.org/src/contrib/Archive/mirai/mirai_2.6.1.tar.gz")

message("Restoring remaining packages from renv.lock...")
renv::restore(prompt = FALSE)

message("Installed versions:")
message("nanonext: ", as.character(utils::packageVersion("nanonext")))
message("mirai: ", as.character(utils::packageVersion("mirai")))

renv::status()
