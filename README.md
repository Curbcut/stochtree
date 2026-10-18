# nashtree (development ownership fork)

Mechanical R-package rename of Curbcut/stochtree at
`0ac0e7d091556d3dd1b8102ac4a010805cad55d1`. No sampler or prediction
algorithm changes are part of this commit. Git ancestry, licenses, upstream
authors, vendored notices, native namespaces and historical JSON fields remain.

Install this checkout into an isolated R library with `R CMD INSTALL .`.
Do not attach stochtree and nashtree together for compatibility comparisons.
Compare them in separate R processes. This fork is not a published release.

Historical `stochtree_version` is retained as a compatibility serialization
field; it is not an assertion of the serving engine identity. Production use
requires a coordinated runtime-contract migration and new qualification.

The upstream project is https://github.com/StochasticTree/stochtree.
Curbcut maintains this fork; upstream correctness fixes require focused
regression review before incorporation. Original author and license information
remains in DESCRIPTION, LICENSE and inst/COPYRIGHTS. Platform support and release
responsibility remain provisional until separate compatibility qualification.
