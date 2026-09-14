# Synthetic native-conditional check; requires only the stochtree R package.
# Run the same script against separate base/fixed package installations.
library(stochtree)
J <- 5L
g <- rep(seq_len(J), each = 6L)
y <- seq(-1, 1, length.out = length(g))
dataset <- stochtree:::createRandomEffectsDataset(g, matrix(1, length(g), 1))
tracker <- stochtree:::createRandomEffectsTracker(g)
model <- stochtree:::createRandomEffectsModel(1L, J)
samples <- stochtree:::createRandomEffectSamples(1L, J, tracker)
residual <- stochtree:::createOutcome(y)
rng <- stochtree:::createCppRNG(454L)
model$set_working_parameter_cov(matrix(1))
model$set_variance_prior_shape(3)
model$set_variance_prior_scale(2)

# Reset to a known state before each draw; this is a conditional check,
# not a posterior-chain convergence test.
u <- numeric(10000)
for (i in seq_along(u)) {
  model$set_working_parameter(1)
  model$set_group_parameters(matrix(0, 1, J))
  model$set_group_parameter_cov(matrix(0.7))
  stochtree:::resetRandomEffectsTracker(tracker, model, dataset, residual, samples)
  residual$update_data(y)
  model$sample_random_effect(dataset, residual, tracker, samples, TRUE, 0.4, rng)
  p <- samples$extract_parameter_samples()
  # v | xi ~ IG(3 + J/2, 2 + sum(xi^2)/2), so this CDF is Uniform(0,1).
  u[i] <- pgamma(1 / p$sigma_samples,
                 shape = 3 + J / 2, rate = 2 + sum(p$xi_samples^2) / 2)
  samples$delete_sample(0L)
}
print(c(expected_CDF_mean = 0.5, observed_CDF_mean = mean(u),
        KS_distance_from_uniform = unname(ks.test(u, "punif")$statistic)))

stopifnot(abs(mean(u) - 0.5) < 0.015, unname(ks.test(u, "punif")$statistic) < 0.025)
