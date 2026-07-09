root <- normalizePath(file.path(getwd(), "..", ".."), winslash = "/", mustWork = TRUE)
source(file.path(root, "R", "utils.R"))
source_project_files(file.path(root, "R"))
