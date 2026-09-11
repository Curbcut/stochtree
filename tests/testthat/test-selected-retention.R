test_that("selected retention matches post-hoc compaction and all scoring draws", {
  set.seed(72)
  x <- data.frame(x = rnorm(60), z = runif(60), cat = factor(rep(letters[1:3], 20)))
  y <- x$x + rnorm(60); xt <- x[1:7, ]
  for (gfr in c(0L, 3L)) for (every in c(1L, 2L)) for (threads in c(1L, 2L)) {
    args <- list(X_train = x, y_train = y, num_gfr = gfr, num_burnin = 8, num_mcmc = 20,
      general_params = list(random_seed = 85, keep_every = every, num_threads = threads),
      mean_forest_params = list(num_trees = 5))
    set.seed(82); full <- do.call(bart, args); full_rng <- .Random.seed
    ids <- c(0L, 6L, 19L)
    set.seed(82); selected <- do.call(bart, c(args, list(X_test = xt, retained_sample_ids = ids)))
    expect_identical(.Random.seed, full_rng)
    expect_s3_class(selected, "bartselected")
    expect_identical(selected$model$mean_forests$num_samples(), length(ids))
    expect_identical(selected$y_hat_train, full$y_hat_train)
    expect_identical(selected$sigma2_global_samples, full$sigma2_global_samples)
    expect_identical(selected$y_hat_test, predict(full, X = xt)$y_hat)
    for (multiplier in list(NULL, 2L)) {
      set.seed(91); expected <- sampleBARTPosteriorPredictive(full, xt, num_draws_per_sample = multiplier)
      seed_after <- .Random.seed
      set.seed(91); actual <- sampleBARTSelectedPosteriorPredictive(selected, multiplier)
      expect_identical(actual, expected)
      expect_identical(.Random.seed, seed_after)
    }
    full$mean_forests$retain_samples(ids)
    full$y_hat_train <- full$y_hat_train[, ids + 1L, drop = FALSE]
    full$sigma2_global_samples <- full$sigma2_global_samples[ids + 1L]
    full$sigma2_leaf_samples <- full$sigma2_leaf_samples[ids + 1L]
    full$model_params$num_samples <- length(ids)
    expect_identical(saveBARTModelToJsonString(selected$model), saveBARTModelToJsonString(full))
    restored <- createBARTModelFromJsonString(saveBARTModelToJsonString(selected$model))
    expect_identical(predict(restored, X = xt), predict(full, X = xt))
    expect_error(saveBARTModelToJsonString(selected), "must be a BART model")
  }
})

test_that("selected IDs and unsupported modes fail before sampling", {
  x <- matrix(seq_len(80) / 80, 40, 2); y <- x[, 1]
  for (ids in list(integer(), c(2, 1), c(1, 1), -1, 10, .5, NA_real_, Inf, "1")) {
    set.seed(15); before <- .Random.seed
    expect_error(bart(x, y, num_mcmc = 10, retained_sample_ids = ids), "retained_sample_ids")
    expect_identical(.Random.seed, before)
  }
  for (extra in list(list(general_params = list(keep_gfr = TRUE)),
    list(general_params = list(keep_burnin = TRUE)), list(general_params = list(num_chains = 2)),
    list(leaf_basis_train = x), list(forest_retention = "importance"),
    list(variance_forest_params = list(num_trees = 2)))) {
    expect_error(do.call(bart, c(list(X_train = x, y_train = y, retained_sample_ids = 0L), extra)), "retention requires")
  }
})

test_that("selected retention supports single samples, fixed variance and observation weights", {
  x <- data.frame(x = seq_len(40) / 40); y <- sin(x$x)
  for (samples in c(1L, 5L)) {
    args <- list(X_train = x, y_train = y, num_gfr = 3, num_burnin = 4,
      num_mcmc = samples, observation_weights = rep(c(1, 2), 20),
      general_params = list(random_seed = 72, sample_sigma2_global = FALSE,
        sigma2_global_init = .7), mean_forest_params = list(num_trees = 3))
    full <- do.call(bart, args)
    selected <- do.call(bart, c(args, list(X_test = x[1:3, , drop = FALSE], retained_sample_ids = 0L)))
    set.seed(71); expected <- sampleBARTPosteriorPredictive(full, x[1:3, , drop = FALSE])
    set.seed(71); expect_identical(sampleBARTSelectedPosteriorPredictive(selected), expected)
    expect_equal(selected$model$mean_forests$num_samples(), 1)
    expect_equal(dim(selected$model$y_hat_train), c(40, 1))
  }
})
