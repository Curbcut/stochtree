# Native binary prototype: initial measured results

Candidate source: `df3260bad7682847a31257baebf8862f2f5c1c0f`, based on the
separate rename commit `126a6320`, preserving the audited fork ancestry.
Pinned Phase 0 artifacts and report remain unchanged. This prototype is not
connected to any serving/export/release workflow and has not been deployed.

## Paired local raw-engine measurements

Three fresh R processes per variant and representative on macOS ARM64, R 4.6.1.
Both modes preload common NASH application dependencies and identical processed
inputs. Timing includes complete model loading and selected raw mean-forest
prediction; binary loading includes complete integrity and structural validation.
It excludes recipes, outcome scaling, random effects, conversion and output IO.
Process peaks cover the whole process, including those common dependencies.
Files are locally warm/uncontrolled, without a residency or cold-cache claim.

| Representative | Legacy load+predict | Binary, all source samples | Binary, selected 300 | Maximum process peak: legacy / all / selected |
|---|---:|---:|---:|---:|
| CMA GDP | 3.676 s | 0.065 s | 0.023 s | 2542 / 271 / 235 MiB |
| CT owner level | 6.000 s | 0.447 s | 0.332 s | 2711 / 368 / 278 MiB |
| CT tenant change | 4.627 s | 0.303 s | 0.201 s | 2304 / 348 / 266 MiB |

All-source-sample variants preserve the source's 1,000 retained samples; CMA
original IDs still refer to its precompaction 2,000-sample population. This
removes stored-sample compaction as an explanation for that variant. It still
uses the new selected-sample evaluator; the legacy API evaluates all stored
samples before subsetting. Load and evaluation timings are recorded separately. Both variants pass the provisional 2x time and
50% process-peak gates on all three representatives. These are raw-engine
microbenchmarks, not a whole-scenario speedup or deployment sizing result.

## Exactness and scope

- Seeded BART, random-intercept BART and BCF training, serialized JSON and restored
  predictions match between the separate renamed and old package processes.
- The renamed legacy importer reproduces all three real reference raw probes.
  All three serialized recipes retain their baseline hashes; a bounded audit
  finds no package-qualified closures, environments, external pointers or
  stochtree strings in those recipes. This is not the entire historical corpus.
- Every retained reachable node, threshold and leaf is byte-identical to the
  original source graph for both all-sample and selected binaries. Source
  prune/grow IDs are traversed rather than assumed to be contiguous or ordered.
- Fixed and mapped predictions agree exactly between native standalone and R
  adapter. Applying the unchanged scale/mean and aligned legacy random-effects
  term reproduces the pinned latent draw probes exactly.
- The Linux x86-64 standalone executable (GCC 13.3) produces byte-identical
  fixed/mapped raw outputs to macOS ARM64 for all three real probes. Its linkage
  contains no R library. This is component evidence, not cross-platform full-system qualification.
- Native contract and converter corruption/index/capability tests pass, including
  ASan/UBSan runs. Thirty repeated real CT load/free cycles reach a stable
  roughly 41-MiB native-process high-water mark after initial allocator settling.

Compact receipts and checksums are in `evidence/20261018/`; large model, input,
raw-draw and binary payloads remain outside Git. Timings record the actual native
library SHA-256 and source commit. Separate zstd distribution receipts compare
local/compressed bytes and verified decompression; these are not transfer-speed
measurements. The loader currently uses owned vectors and a temporary read
buffer, not mmap.

Full scientific preprocessing, random-effects execution, variance/probit/BCF,
scenario composition and qualification retain their existing implementations.
The current core covers only the declared raw scalar numeric BART subset.
The binary-with-legacy-native-predictor alternative was not implemented; the
packed reader/evaluator is the measured prototype, compared with the old JSON
loader/evaluator. Complete caller feature-order context validation, production
contracts, fsync/publication semantics, full-system draw-level equivalence and
resource qualification remain later integration gates. Windows is unqualified.

Parent-memory profiling belongs to the separate nash working-set effort. These
forest results do not explain or eliminate the large parent working set.
