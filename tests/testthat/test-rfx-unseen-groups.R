rfx_unseen_fixture <- function(seed = 917) {
  set.seed(seed)
  n_per <- 25
  g <- rep(letters[1:4], each = n_per)
  n <- length(g)
  x <- data.frame(a = rnorm(n), b = runif(n))
  y <- 2 * x$a + rep(c(-4, -1, 2, 5), each = n_per) + rnorm(n, 0, 0.5)
  list(x = x, y = y, g = g)
}

test_that("the unseen-group policy is validated and stored", {
  d <- rfx_unseen_fixture()
  expect_error(
    bart(X_train = d$x, y_train = d$y, rfx_group_ids_train = d$g,
      num_gfr = 0, num_burnin = 2, num_mcmc = 2,
      random_effects_params = list(model_spec = "intercept_only",
        unseen_groups = "average")),
    "unseen_groups must be 'error' or 'mean'"
  )
  fit <- bart(X_train = d$x, y_train = d$y, rfx_group_ids_train = d$g,
    num_gfr = 0, num_burnin = 2, num_mcmc = 4,
    random_effects_params = list(model_spec = "intercept_only"))
  expect_identical(fit$model_params$rfx_unseen_groups, "error")
  expect_error(
    predict(fit, X = d$x, rfx_group_ids = rep("z", nrow(d$x)), type = "mean"),
    "must have been present in rfx_group_ids_train"
  )
})

test_that("unseen groups take the mean group intercept in every draw", {
  d <- rfx_unseen_fixture()
  fit <- bart(X_train = d$x, y_train = d$y, rfx_group_ids_train = d$g,
    num_gfr = 0, num_burnin = 10, num_mcmc = 20,
    general_params = list(random_seed = 5),
    random_effects_params = list(model_spec = "intercept_only",
      unseen_groups = "mean"))
  expect_identical(fit$model_params$rfx_unseen_groups, "mean")

  unseen <- d$g
  unseen[1:5] <- "unseen-cma"
  seen_only <- predict(fit, X = d$x, rfx_group_ids = d$g,
    type = "posterior", terms = "rfx")
  mixed <- predict(fit, X = d$x, rfx_group_ids = unseen,
    type = "posterior", terms = "rfx")
  beta <- fit$rfx_samples$extract_parameter_samples()$beta_samples *
    fit$model_params$outcome_scale
  expected <- colMeans(beta)
  for (row in 1:5) {
    expect_equal(as.numeric(mixed[row, ]), as.numeric(expected))
  }
  expect_equal(mixed[6:nrow(d$x), ], seen_only[6:nrow(d$x), ])

  # Every prediction entry point honours the policy.
  expect_silent(sampleBARTPosteriorPredictive(fit, X = d$x,
    rfx_group_ids = unseen, num_draws_per_sample = 1L))
  all_unseen <- rep("unseen-cma", nrow(d$x))
  every_row <- predict(fit, X = d$x, rfx_group_ids = all_unseen,
    type = "posterior", terms = "rfx")
  expect_equal(as.numeric(every_row[1, ]), as.numeric(expected))
})

test_that("test-set and serialized models honour the policy", {
  d <- rfx_unseen_fixture()
  unseen <- d$g
  unseen[1:5] <- "unseen-cma"
  fit <- bart(X_train = d$x, y_train = d$y, X_test = d$x,
    rfx_group_ids_train = d$g, rfx_group_ids_test = unseen,
    num_gfr = 0, num_burnin = 10, num_mcmc = 20,
    general_params = list(random_seed = 6),
    random_effects_params = list(model_spec = "intercept_only",
      unseen_groups = "mean"))
  expect_equal(nrow(fit$y_hat_test), nrow(d$x))
  expect_true(all(is.finite(fit$y_hat_test)))

  path <- file.path(tempdir(), "rfx-unseen-model.json")
  on.exit(unlink(path), add = TRUE)
  saveBARTModelToJsonFile(fit, path)
  reloaded <- createBARTModelFromJsonFile(path)
  expect_identical(reloaded$model_params$rfx_unseen_groups, "mean")
  expect_equal(
    predict(reloaded, X = d$x, rfx_group_ids = unseen, type = "mean", terms = "y_hat"),
    predict(fit, X = d$x, rfx_group_ids = unseen, type = "mean", terms = "y_hat")
  )
})
