test_that("bulk forest retention preserves sample values and order", {
  for (dimension in c(1L, 2L)) {
    forest <- createForestSamples(3L, dimension, dimension == 1L, FALSE)
    legacy <- createForestSamples(3L, dimension, dimension == 1L, FALSE)
    for (i in 0:9) {
      forest$add_forest_with_constant_leaves(rep(i + .5, dimension))
      legacy$add_forest_with_constant_leaves(rep(i + .5, dimension))
    }
    keep <- c(0L, 3L, 8L, 9L)
    forest$retain_samples(keep)
    for (i in sort(setdiff(0:9, keep), decreasing = TRUE)) legacy$delete_sample(i)
    expect_identical(forest$num_samples(), legacy$num_samples())
    a <- tempfile(); b <- tempfile()
    on.exit(unlink(c(a, b)), add = TRUE)
    forest$save_json(a); legacy$save_json(b)
    expect_identical(readLines(a), readLines(b))
    before <- readLines(a)
    for (invalid in list(c(1, 0), c(0, 0), -1, 4, NA_real_, Inf, .5, "1")) {
      expect_error(forest$retain_samples(invalid), "strictly increasing")
      forest$save_json(a)
      expect_identical(readLines(a), before)
    }
    expect_error(stochtree:::retain_samples_forest_container_cpp(
      forest$forest_container_ptr, c(0L, 0L)), "strictly increasing")
    forest$retain_samples(0:3)
    forest$save_json(a)
    expect_identical(readLines(a), before)
    forest$retain_samples(integer())
    expect_equal(forest$num_samples(), 0L)
    forest$add_forest_with_constant_leaves(rep(5, dimension))
    expect_equal(forest$num_samples(), 1L)
  }
})
