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
