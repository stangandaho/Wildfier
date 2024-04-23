options(repos = c(CRAN = "https://cloud.r-project.org"))
# Install packages if missed
r_packages <- c("shiny", "shinyjs", "reticulate", "fs", "shinycssloaders", "DT")

for (pkg in r_packages) {
  if (! pkg %in% rownames(installed.packages())) {
    install.packages(pkg)
  }
  rm(pkg)
}

# load package
for (pkg in r_packages) {
  library(pkg, character.only = TRUE)
  rm(pkg)
}

# Python modules
## Install python if not avalaible
if (!reticulate::py_available(initialize = TRUE)) {
  reticulate::install_python()
}

# Install and import Python modules if missing
py_packages <- c("ultralytics", "piexif", "onnx", "onnxruntime")

## Virtual environnement
if (!reticulate::virtualenv_exists(envname = "wildfier_env")) {
  reticulate::virtualenv_create(envname = "wildfier_env")
  reticulate::use_python(python = virtualenv_python("wildfier_env"))
  reticulate::use_virtualenv("wildfier_env")
}

#reticulate::use_virtualenv("wildfier_env")

for (py_pkg in py_packages) {
  if (!py_module_available(py_pkg)) {
    reticulate::py_install(py_pkg, method = "virtualenv")
  }
  rm(py_pkg)
}

# Import Python modules
ult <- import("ultralytics")
piexif <- import("piexif")

rm(r_packages, py_packages)
