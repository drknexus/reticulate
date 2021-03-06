
#' R Interface to Python
#' 
#' R interface to Python modules, classes, and functions. When calling into 
#' Python R data types are automatically converted to their equivalent Python 
#' types. When values are returned from Python to R they are converted back to R
#' types. The reticulate package is compatible with all versions of Python >= 2.7.
#' Integration with NumPy requires NumPy version 1.6 or higher.
#' 
#' @docType package
#' @name reticulate
#' @useDynLib reticulate
#' @importFrom Rcpp evalCpp
NULL

# package level mutable global state
.globals <- new.env(parent = emptyenv())
.globals$use_python_versions <- c()
.globals$py_config <- NULL
.globals$delay_load_module <- NULL
.globals$suppress_warnings_handlers <- list()



.onUnload <- function(libpath) {
  if (is_python_initialized())
    py_finalize();
}


is_python_initialized <- function() {
  !is.null(.globals$py_config)
}


ensure_python_initialized <- function(required_module = NULL) {
  if (!is_python_initialized()) {
    if (is.null(required_module))
      required_module <- .globals$delay_load_module
    .globals$py_config <- initialize_python(required_module)
  }
}

initialize_python <- function(required_module = NULL) {

  # find configuration
  config <- py_discover_config(required_module)

  # check for basic python prerequsities
  if (is.null(config)) {
    stop("Installation of Python not found, Python bindings not loaded.")
  } else if (!file.exists(config$libpython)) {
    stop("Python shared library '", config$libpython, "' not found, Python bindings not loaded.")
  } else if (is_incompatible_arch(config)) {
    stop("Your current architecture is ", python_arch(), " however this version of ",
         "Python is compiled for ", config$architecture, ".")
  }

  # check numpy version and provide a load error message if we don't satisfy it
  if (is.null(config$numpy) || config$numpy$version < "1.6") 
    numpy_load_error <- "installation of Numpy >= 1.6 not found"
  else
    numpy_load_error <- ""
  
  
  # add the python bin dir to the PATH for anaconda on windows
  # (see https://github.com/rstudio/reticulate/issues/20)
  if (isTRUE(config$anaconda) && is_windows()) {
    Sys.setenv(PATH = paste(normalizePath(dirname(config$python)), 
                            Sys.getenv("PATH"),
                            sep = .Platform$path.sep))  
  }
  
  # initialize python
  py_initialize(config$python,
                config$libpython,
                config$pythonhome,
                config$virtualenv_activate,
                config$version >= "3.0",
                numpy_load_error)
  
  # if we have a virtualenv then set the VIRTUAL_ENV environment variable
  if (nzchar(config$virtualenv_activate))
    Sys.setenv(VIRTUAL_ENV = path.expand(dirname(dirname(config$virtualenv_activate))))

  # set available flag indicating we have py bindings
  config$available <- TRUE

  # add our python scripts to the search path
  py_run_string_impl(paste0("import sys; sys.path.append('",
                       system.file("python", package = "reticulate") ,
                       "')"))

  # return config
  config
}




