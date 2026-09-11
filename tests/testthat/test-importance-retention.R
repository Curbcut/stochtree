test_that("importance retention preserves retained counts, draws and RNG state", {
  set.seed(720)
  x <- data.frame(a = rnorm(60), b = runif(60), c = factor(rep(letters[1:3], 20)),
                  d = ordered(rep(1:3, 20)))
  y <- x$a + rnorm(60)
  for (gfr in c(0L, 3L)) for (keep_gfr in c(FALSE, TRUE))
    for (keep_burnin in c(FALSE, TRUE)) for (every in c(1L, 2L)) {
      args <- list(X_train = x, y_train = y, num_gfr = gfr, num_burnin = 4,
        num_mcmc = 8, general_params = list(random_seed = 31, keep_gfr = keep_gfr,
          keep_burnin = keep_burnin, keep_every = every),
        mean_forest_params = list(num_trees = 4))
      set.seed(521); full <- do.call(bart, args); full_rng <- .Random.seed
      set.seed(521); compact <- do.call(bart, c(args, list(forest_retention = "importance")))
      expect_identical(.Random.seed, full_rng)
      expect_s3_class(compact, "bartimportance")
      expect_false(inherits(compact, "bartmodel"))
      expect_null(compact$mean_forests)
      expect_identical(compact$split_counts,
        full$mean_forests$get_aggregate_split_counts(length(compact$split_counts)))
      for (field in c("y_hat_train", "sigma2_global_samples", "sigma2_leaf_samples",
                      "model_params", "train_set_metadata"))
        expect_identical(compact[[field]], full[[field]], info = field)
      expect_identical(unserialize(serialize(compact, NULL)), compact)
    }
})

test_that("importance output stores only initialization forests and rejects prediction", {
  captured <- list(); original <- createForestSamples
  local_mocked_bindings(createForestSamples = function(...) {
    value <- original(...); captured[[length(captured) + 1L]] <<- value; value
  })
  x <- matrix(seq_len(80) / 80, 40, 2); y <- x[, 1]
  fit <- bart(x, y, num_gfr = 3, num_burnin = 5, num_mcmc = 1000,
    mean_forest_params = list(num_trees = 4),
    general_params = list(random_seed = 7), forest_retention = "importance")
  expect_identical(captured[[1L]]$num_samples(), 0L)
  expect_equal(ncol(fit$y_hat_train), 1000)
  expect_equal(fit$model_params$num_samples, 1000)
  expect_error(predict(fit, X = x), "do not retain forests")
  expect_error(saveBARTModelToJsonString(fit), "must be a BART model")
  gfr <- bart(x, y, num_gfr = 3, num_burnin = 0, num_mcmc = 0,
    mean_forest_params = list(num_trees = 4),
    general_params = list(random_seed = 7), forest_retention = "importance")
  expect_equal(gfr$model_params$num_samples, 3)
  expect_identical(gfr$split_counts, captured[[2L]]$get_aggregate_split_counts(2))
  expect_identical(captured[[2L]]$num_samples(), 3L)
})

test_that("unsupported importance policies fail before altering the RNG", {
  x <- matrix(seq_len(80) / 80, 40, 2); y <- x[, 1]
  variants <- list(list(X_test = x), list(leaf_basis_train = x),
    list(rfx_group_ids_train = rep(1:2, 20)),
    list(variance_forest_params = list(num_trees = 2)),
    list(general_params = list(num_chains = 2, random_seed = 3)),
    list(previous_model_json = "invalid"),
    list(general_params = list(outcome_model = OutcomeModel("binary", "probit"))))
  for (extra in variants) {
    set.seed(87); before <- .Random.seed
    expect_error(do.call(bart, c(list(X_train = x, y_train = y,
      forest_retention = "importance"), extra)), "Importance retention requires")
    expect_identical(.Random.seed, before)
  }
  expect_error(bart(x, y, forest_retention = "typo"), "arg")
})
