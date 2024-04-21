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
# Install and import Python modules if missing
py_packages <- c("ultralytics", "piexif", "onnx", "onnxruntime")

for (py_pkg in py_packages) {
  if (!py_module_available(py_pkg)) {
    py_install(py_pkg)
  }
  rm(py_pkg)
}

# Import Python modules
ult <- import("ultralytics")
piexif <- import("piexif")

rm(r_packages, py_packages)
