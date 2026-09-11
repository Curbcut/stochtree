#' @export
predict.bartimportance <- function(object, ...) {
  stop("Importance summaries do not retain forests for prediction on new data.", call. = FALSE)
}
