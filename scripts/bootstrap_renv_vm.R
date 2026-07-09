source("renv/activate.R")

options(repos = c(CRAN = "https://cloud.r-project.org"))

message("Installing pinned nanonext and mirai versions from CRAN Archive...")
renv::install(
  "https://cran.r-project.org/src/contrib/Archive/nanonext/nanonext_1.8.1.tar.gz",
  rebuild = TRUE,
  prompt = FALSE
)
renv::install(
  "https://cran.r-project.org/src/contrib/Archive/mirai/mirai_2.6.1.tar.gz",
  rebuild = TRUE,
  prompt = FALSE
)

message("Restoring remaining packages from renv.lock...")
renv::restore(prompt = FALSE)

message("Installed versions:")
message("nanonext: ", as.character(utils::packageVersion("nanonext")))
message("mirai: ", as.character(utils::packageVersion("mirai")))

renv::status()
