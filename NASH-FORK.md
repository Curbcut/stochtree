# Temporary NASH dependency fork

This R-installable branch is generated with `Rscript cran-bootstrap.R 0 0 1`
from the `codex/nash-fixes` source branch at commit
`67cb458b` in Curbcut/stochtree.

It combines these local bug fixes:

- Correct MCMC grow and prune proposal probabilities (5c5f2e8a).
- Fix extrema calculation in MCMC split helpers (1c846cfd).
- Fix NaN ordering in GFR feature presorting (7d364ad2).

NASH pins the generated R-package commit in its DESCRIPTION Remotes field.
After upstream includes all three fixes in a verified release, remove that
Remotes entry and require the fixed upstream version in Imports.

## Numeric preprocessing follow-up

The `codex/numeric-preprocessing` branch starts at the exact generated package
commit `06fbcc6bf3bd57c7d5caee475895fa5db32646d6`. It batches ordinary numeric
covariate binding in training and prediction preprocessing while preserving
categorical processing and retaining pairwise behavior for attributed columns.
Native sampler sources are unchanged. The added numeric-binding tests compare
full preprocessing metadata and seeded BART draws and split counts with the
previous numeric loop.
