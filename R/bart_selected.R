#' Draw predictions from every sampled iteration of a selected-retention fit
#' @param object A `bartselected` result from [bart()] with test covariates.
#' @param num_draws_per_sample Same multiplier as [sampleBARTPosteriorPredictive()].
#' @returns Predictive draws for the test rows supplied to `bart`, using all posterior iterations.
#' @export
sampleBARTSelectedPosteriorPredictive <- function(object, num_draws_per_sample = NULL) {
  if (!inherits(object, "bartselected") || is.null(object$y_hat_test)) {
    stop("Expected a selected-retention BART result with test predictions.")
  }
  n <- nrow(object$y_hat_test)
  variance <- if (object$model_params$sample_sigma2_global) {
    matrix(rep(object$sigma2_global_samples, each = n), nrow = n)
  } else object$model_params$sigma2_init
  sample_gaussian_predictive_draws(object$y_hat_test, variance,
    object$model_params$num_samples, n, num_draws_per_sample)
}
