\name{sampleBARTSelectedPosteriorPredictive}
\alias{sampleBARTSelectedPosteriorPredictive}
\title{Draw predictions from all iterations of a selected-retention fit}
\usage{sampleBARTSelectedPosteriorPredictive(object, num_draws_per_sample = NULL)}
\arguments{
\item{object}{A \code{bartselected} result from \code{bart()} with test covariates.}
\item{num_draws_per_sample}{Same multiplier as \code{sampleBARTPosteriorPredictive()}.}
}
\description{Generate predictions for the original test rows using every sampled iteration, independently of which forests are retained.}
\value{An array of posterior predictive draws, with the same ordering and multiplier policy as \code{sampleBARTPosteriorPredictive()}.}
