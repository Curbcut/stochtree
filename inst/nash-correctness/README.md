# NASH sampler correctness regressions

Run the installed package's native variance conditional check:

```sh
Rscript inst/nash-correctness/variance-conditional.R
```

It tests 10,000 native conditional draws against the analytic inverse-gamma
distribution. With seed 454 the corrected CDF mean is 0.50021451 and KS distance
is 0.00812952. The old conditional gives 0.5958146 and 0.1438309 and fails.

Build the partition regression from the package root (supply the local BH include path):

```sh
clang++ -std=c++17 -O2 -I src/include -I /path/to/BH/include \
  inst/nash-correctness/reconstruction-regression.cpp src/partition_tracker.cpp \
  src/tree.cpp src/data.cpp src/io.cpp -o /tmp/reconstruction-regression
/tmp/reconstruction-regression
```

It checks numerical and categorical trees with recycled IDs against direct tree
evaluation, then continues pruning/growing and reconstructs again. Corrected
code reports zero membership/structure failures.

Focused R suite: `NOT_CRAN=true Rscript -e 'testthat::test_local(".",
filter="^(bcf|forest|forest-container|random-effects|importance-retention)$")'`.
On macOS ARM64 / R 4.6.1 this passed 317 assertions, no warnings or skips.
These checks certify the specific fixes, not whole-model convergence.
