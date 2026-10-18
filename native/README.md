# Inference-only binary prototype

This is an opt-in research prototype layered on the separately reviewed package
rename. It is not connected to the NASH serving runtime, manifests, images or
release commands. No deployment, promotion or baseline rewrite is part of it.
See [FORMAT.md](FORMAT.md) for semantics, limitations and the checked format.

Build the native core and standalone tools without R:

```
cmake -S native -B /tmp/ntf-build -DCMAKE_BUILD_TYPE=Release
cmake --build /tmp/ntf-build -j 2
ctest --test-dir /tmp/ntf-build --output-on-failure
python3 native/test_converter.py /tmp/ntf-build
```

Repeat with `-DNASHTREE_SANITIZE=ON` in a different debug build directory. The
GitHub workflow builds/tests in a container with no R executable. All executables
use the same `src/inference.cpp`; the converter's JSON dependency is not linked
into the inference reader/predictor. `ntf-lifetime` records 30 load/free process
high-water marks on Unix; the measurements do not subtract allocator retention.

Install the R package in a new library with `R CMD INSTALL --library=... .`.
Generated bindings come from `cpp11::cpp_register('.')`; the types header must
match the package name. The internal `ntf_*` R functions expose the same native
core; they intentionally are not a replacement for the public modelling API.

For each real forest, copy the frozen compressed forest, `probe.rds`, `draws.rds`
and its existing configuration as `source.json` into a separate input directory.
Never alter the pinned root or old evidence. In a legacy-only process with the
current isolated nash library, run:

```
Rscript native/prepare-reference.R /immutable/copy /new/reference
python3 native/convert-reference.py /new/reference /tmp/ntf-build
python3 native/run-reference.py /new/reference /tmp/ntf-build
Rscript native/validate-reference.R /new/reference
python3 native/structural.py /new/reference
```

The preparation verifies the source SHA-256 and unchanged latent draw reference,
exports real preprocessed numeric inputs, and carries actual original sample
maps. The converter checks those IDs independently against producer metadata.
It makes separate all-sample and requested-sample binaries. Validation compares
raw fixed/mapped results and standalone/adapter outputs exactly, then applies
the unchanged scale/mean and legacy random-effects term to compare latent draws.
This does not implement new random effects, predictive noise or system execution.
`validate-rename-import.R` separately tests historical imports with the renamed
legacy engine, without relying on attaching both engine packages in one session.

Run three fresh processes per variant with both isolated R libraries in R_LIBS:

```
NASHTREE_SOURCE_COMMIT=$(git rev-parse HEAD) python3 native/benchmark.py \
  /new/reference /immutable/copy/forest.json.zst /new/timings
```

The paired boundary starts with identical already preprocessed inputs and ends
with selected raw mean-forest values. Both modes preload the same NASH application
dependencies. It includes full model load, binary integrity checking and first
prediction, not just opening a handle. RFX/recipes/scaling, conversion and output
writing are excluded equally. Process peaks cover the entire fresh R process.
All-sample binaries isolate the packing/loader benefit from compaction. No host
cache eviction is performed; these are local warm/uncontrolled results.

The corpus metadata is not a fixture decoder for opaque stage-replay objects.
BCF and other unsupported capabilities keep their verified legacy path. Complete
runtime-contract integration and full scenario qualification are later work.
