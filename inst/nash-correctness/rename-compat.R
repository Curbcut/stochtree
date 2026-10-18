# Run once per engine in separate R processes, then compare the two output RDS files.
args <- commandArgs(TRUE)
stopifnot(length(args) == 2L, args[[1]] %in% c("stochtree", "nashtree"))
engine <- asNamespace(args[[1]])
get_engine <- function(name) get(name, engine)
x <- data.frame(x = seq(-1, 1, length.out = 40), z = rep(c(0, 1), 20))
y <- sin(x$x) + x$z / 3
results <- list()
for (kind in c("bart", "rfx", "bcf")) {
  set.seed(817L)
  if (kind == "bcf") {
    model <- get_engine("bcf")(
      X_train = x, Z_train = as.matrix(x$z), y_train = y, propensity_train = rep(0.5,nrow(x)),
      num_gfr = 2L, num_burnin = 1L, num_mcmc = 4L,
      general_params = list(random_seed = 918L),
      prognostic_forest_params = list(num_trees = 3L),
      treatment_effect_forest_params = list(num_trees = 2L)
    )
    predict_args <- list(object = model, X = x, Z = as.matrix(x$z), propensity = rep(0.5,nrow(x)))
    serial <- get_engine("saveBCFModelToJsonString")(model)
    restored <- get_engine("createBCFModelFromJsonString")(serial)
  } else {
    extras <- if (kind == "rfx") list(rfx_group_ids_train = rep(1:4, each = 10), random_effects_params = list(model_spec = "intercept_only")) else list()
    model <- do.call(get_engine("bart"), c(list(
      X_train = x, y_train = y, num_gfr = 2L, num_burnin = 1L, num_mcmc = 4L,
      general_params = list(random_seed = 918L), mean_forest_params = list(num_trees = 3L)
    ), extras))
    predict_args <- c(list(object = model, X = x),
      if (kind == "rfx") list(rfx_group_ids = rep(1:4, each = 10)) else list())
    serial <- get_engine("saveBARTModelToJsonString")(model)
    restored <- get_engine("createBARTModelFromJsonString")(serial)
  }
  predictions <- do.call(stats::predict, predict_args)
  predict_args$object <- restored
  stopifnot(identical(predictions, do.call(stats::predict, predict_args)))
  results[[kind]] <- list(predictions = predictions, json = serial)
}
saveRDS(results, args[[2]], version = 3)
