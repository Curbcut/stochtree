legacy_numeric_binding <- function(numeric_df) {
  Xnum <- double(0)
  for (i in seq_len(ncol(numeric_df))) {
    stopifnot(is.numeric(numeric_df[, i]))
    Xnum <- cbind(Xnum, numeric_df[, i])
  }
  Xnum
}

test_that("batched numeric binding retains training and prediction contracts", {
  mixed <- data.frame(a = c(1L, NA_integer_, 3L), b = c(1.5, NaN, Inf),
    group = factor(c("a", "b", "a")),
    ordinal = ordered(c("low", "high", "low")),
    text = c("x", "y", "x"), row.names = c("r1", "r2", "r3"))
  cases <- list(mixed, mixed[c("a")], mixed[c("a", "b")],
    mixed[c("group", "ordinal", "text")], mixed[FALSE, c("a", "b")],
    mixed[1, c("a", "b")], data.frame(a = I(1:3), b = 3:1))
  actual <- lapply(cases, function(x) {
    trained <- preprocessTrainDataFrame(x)
    list(train = trained, prediction = preprocessPredictionDataFrame(x, trained$metadata))
  })
  local_mocked_bindings(bindNumericCovariates = legacy_numeric_binding)
  for (i in seq_along(cases)) {
    trained <- preprocessTrainDataFrame(cases[[i]])
    expect_identical(actual[[i]]$train, trained)
    expect_identical(actual[[i]]$prediction,
      preprocessPredictionDataFrame(cases[[i]], trained$metadata))
  }
})

test_that("non-numeric columns retain validation errors", {
  expect_error(preprocessTrainDataFrame(data.frame(x = c(TRUE, FALSE))))
  metadata <- preprocessTrainDataFrame(data.frame(x = 1:2))$metadata
  expect_error(preprocessPredictionDataFrame(data.frame(x = c(TRUE, FALSE)), metadata))
})

test_that("numeric binding preserves seeded BART samples and split counts", {
  x <- data.frame(a = seq(-1, 1, length.out = 30), b = rep(1:3, 10),
    group = factor(rep(c("a", "b"), 15)))
  fit <- function() bart(x, sin(x$a) + x$b, X_test = x[1:5, ],
    num_gfr = 2, num_burnin = 2, num_mcmc = 5,
    general_params = list(random_seed = 123, num_threads = 1),
    mean_forest_params = list(num_trees = 3, min_samples_leaf = 2))
  actual <- fit()
  local_mocked_bindings(bindNumericCovariates = legacy_numeric_binding)
  expected <- fit()
  expect_identical(actual$y_hat_train, expected$y_hat_train)
  expect_identical(actual$y_hat_test, expected$y_hat_test)
  num_features <- length(actual$train_set_metadata$feature_types)
  expect_identical(actual$mean_forests$get_aggregate_split_counts(num_features),
    expected$mean_forests$get_aggregate_split_counts(num_features))
})

test_that("shared numeric inputs stay shared through binding and BART", {
  skip_if_not_installed("mori")
  set.seed(921)
  original <- list(a = rnorm(2000), b = rep(c(1L, NA_integer_, 3L, 4L), 500))
  shared <- mori::share(original)
  a <- shared$a
  b <- shared$b
  x <- data.frame(a = a, b = b)
  before <- list(serialize(a, NULL), serialize(b, NULL))
  expect_lt(length(before[[1L]]), 1000)
  expect_lt(length(before[[2L]]), 1000)
  unchanged <- function() {
    expect_identical(serialize(a, NULL), before[[1L]])
    expect_identical(serialize(b, NULL), before[[2L]])
  }
  expected <- legacy_numeric_binding(as.data.frame(original))
  expect_identical(bindNumericCovariates(x), expected)
  unchanged()
  trained <- preprocessTrainDataFrame(x)
  expect_identical(preprocessPredictionDataFrame(x, trained$metadata),
    preprocessPredictionDataFrame(as.data.frame(original), trained$metadata))
  unchanged()
  fit <- function(data) bart(data, original$a, num_gfr = 2,
    num_burnin = 2, num_mcmc = 5, mean_forest_params = list(num_trees = 3),
    general_params = list(random_seed = 37, num_threads = 1),
    forest_retention = "importance")
  actual <- fit(x)
  expected_fit <- fit(as.data.frame(original))
  expect_identical(actual$split_counts, expected_fit$split_counts)
  expect_identical(actual$sigma2_global_samples, expected_fit$sigma2_global_samples)
  rm(actual, expected_fit, trained)
  invisible(gc())
  unchanged()
})


test_that("outcome summaries and BART preserve shared outcome vectors", {
  skip_if_not_installed("mori")
  set.seed(38)
  y <- mori::share(rnorm(2000))
  before <- serialize(y, NULL)
  ordinary <- y[]
  for (fun in list(sum_cpp, mean_cpp, var_cpp, sd_cpp)) {
    expect_identical(fun(y), fun(ordinary))
    expect_identical(serialize(y, NULL), before)
  }
  x <- data.frame(x = seq_len(length(y)))
  fit <- function(outcome) bart(x, outcome, num_gfr = 2, num_burnin = 2,
    num_mcmc = 5, mean_forest_params = list(num_trees = 3),
    general_params = list(random_seed = 31, num_threads = 1),
    forest_retention = "importance")
  actual <- fit(y)
  expected <- fit(ordinary)
  expect_identical(actual$split_counts, expected$split_counts)
  expect_identical(actual$sigma2_global_samples, expected$sigma2_global_samples)
  invisible(gc())
  expect_identical(serialize(y, NULL), before)
})
