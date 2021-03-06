#' Watches code and tests for changes, rerunning tests as appropriate.
#'
#' The idea behind `auto_test()` is that you just leave it running while
#' you develop your code.  Everytime you save a file it will be automatically
#' tested and you can easily see if your changes have caused any test
#'  failures.
#'
#' The current strategy for rerunning tests is as follows:
#'
#' - if any code has changed, then those files are reloaded and all tests
#'   rerun
#' - otherwise, each new or modified test is run
#'
#' In the future, `auto_test()` might implement one of the following more
#' intelligent alternatives:
#'
#' - Use codetools to build up dependency tree and then rerun tests only
#'   when a dependency changes.
#' - Mimic ruby's autotest and rerun only failing tests until they pass,
#'   and then rerun all tests.
#
#' @seealso [auto_test_package()]
#' @export
#' @param code_path path to directory containing code
#' @param test_path path to directory containing tests
#' @param reporter test reporter to use
#' @param env environment in which to execute test suite.
#' @keywords debugging
auto_test <- function(code_path, test_path, reporter = default_reporter(),
                      env = test_env()) {
  reporter <- find_reporter(reporter)
  code_path <- normalizePath(code_path)
  test_path <- normalizePath(test_path)

  # Start by loading all code and running all tests
  source_dir(code_path, env = env)
  test_dir(test_path, env = env, reporter = reporter$clone(deep = TRUE))

  # Next set up watcher to monitor changes
  watcher <- function(added, deleted, modified) {
    changed <- normalizePath(c(added, modified))

    tests <- changed[starts_with(changed, test_path)]
    code <- changed[starts_with(changed, code_path)]

    if (length(code) > 0) {
      # Reload code and rerun all tests
      cat("Changed code: ", paste0(basename(code), collapse = ", "), "\n")
      cat("Rerunning all tests\n")
      source_dir(code_path, env = env)
      test_dir(test_path, env = env, reporter = reporter$clone(deep = TRUE))
    } else if (length(tests) > 0) {
      # If test changes, rerun just that test
      cat("Rerunning tests: ", paste0(basename(tests), collapse = ", "), "\n")
      test_files(tests, env = env, reporter = reporter$clone(deep = TRUE))
    }

    TRUE
  }
  watch(c(code_path, test_path), watcher)

}

#' Watches a package for changes, rerunning tests as appropriate.
#'
#' @param pkg path to package
#' @export
#' @param reporter test reporter to use
#' @keywords debugging
#' @seealso [auto_test()] for details on how method works
auto_test_package <- function(pkg = ".", reporter = default_reporter()) {
  if (!requireNamespace("devtools", quietly = TRUE)) {
    stop("devtools required to run auto_test_package(). Please install.",
      call. = FALSE)
  }

  pkg <- devtools::as.package(pkg)

  reporter <- find_reporter(reporter)
  code_path <- normalizePath(file.path(pkg$path, "R"))
  test_path <- normalizePath(file.path(pkg$path, "tests", "testthat"))

  # Start by loading all code and running all tests
  env <- devtools::load_all(pkg)$env
  withr::with_envvar(
    devtools::r_env_vars(),
    test_dir(test_path, env = env, reporter = reporter$clone(deep = TRUE))
  )

  # Next set up watcher to monitor changes
  watcher <- function(added, deleted, modified) {
    changed <- normalizePath(c(added, modified))

    tests <- changed[starts_with(changed, test_path)]
    code <- changed[starts_with(changed, code_path)]

    if (length(code) > 0) {
      # Reload code and rerun all tests
      cat("Changed code: ", paste0(basename(code), collapse = ", "), "\n")
      cat("Rerunning all tests\n")
      env <<- devtools::load_all(pkg, quiet = TRUE)$env
      withr::with_envvar(
        devtools::r_env_vars(),
        test_dir(test_path, env = env, reporter = reporter$clone(deep = TRUE))
      )
    } else if (length(tests) > 0) {
      # If test changes, rerun just that test
      cat("Rerunning tests: ", paste0(basename(tests), collapse = ", "), "\n")
      withr::with_envvar(
        devtools::r_env_vars(),
        test_files(tests, env = env, reporter = reporter$clone(deep = TRUE))
      )
    }

    TRUE
  }
  watch(c(code_path, test_path), watcher)

}
