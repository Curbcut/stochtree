# nashtree_forest_v1 prototype

Experimental inference-only data, not a published runtime contract. The reference
is Curbcut/stochtree `0ac0e7d091556d3dd1b8102ac4a010805cad55d1`.
Existing forest files are read-only inputs. Conversion writes a new artifact.

## Native boundary and supported subset

`src/include/nashtree/inference.h` and `src/inference.cpp` define the same core
used by the thin cpp11 adapter and the standalone CLI. They have no R headers,
R allocations, callbacks, RNG, Eigen, JSON parser or cloud dependencies. The
conversion tool alone uses the already vendored nlohmann JSON implementation.
All native handles own their vectors with RAII; no pointer crosses a worker.

Supported operation: raw, identity-link, continuous, constant scalar-leaf BART
mean forests, numeric splits, explicit original posterior IDs, numeric binary64
inputs. A value <= threshold routes left; NaN routes left, exactly as the pinned
fork. Sum trees in original order starting at +0.0. No reassociation, FMA-based
reduction, quantization, native RNG, or altered draw ordering.

Fixed prediction consumes a strided matrix view and returns rows x selected IDs
in column-major order; selected IDs may be reordered/repeated. Mapped prediction
consumes one explicit sample ID per input row and returns one value per row.
Callers own buffers, their dimensions, preprocessing and feature order. Both
operations validate bounds and IDs before writing outputs. The raw API does not
execute recipes or inspect R column names. An eventual production adapter must
validate a preprocessing/column-order context before calling it.

BCF, nonconstant/basis leaves, categorical splits, variance/probit/other links
are refused by conversion. Random effects, outcome scaling, predictive noise,
recipes and system composition remain outside the raw-forest core. CMA raw
forest coverage is not a claim that the entire CMA pipeline is R-independent.
Producer metadata, including aligned RFX samples, remains in the metadata
section; the current comparison applies the unchanged legacy RFX term. Legacy
model dependencies remain required for those operations.

## Encoding

All integer fields use little-endian, explicitly sized integers; numeric values
are IEEE754 binary64. The header is 128 bytes:

| Byte offset | Field |
|---|---|
| 0 | 8 bytes `NASHNTF\0` |
| 8, 12 | uint32 major=1, minor=0 |
| 16, 20 | uint32 endian marker=0x01020304, required capabilities=1 |
| 24 | uint64 total file bytes |
| 32, 40, 48, 56 | uint64 retained samples, trees, nodes, metadata bytes |
| 64, 72 | uint64 feature count, original sample count |
| 80 | uint64 CRC64-ECMA of complete file, with this slot zeroed |
| 88, 96, 104, 112, 120 | uint64 offsets to IDs, sample/tree offsets, nodes, metadata |

Sections are contiguous and their canonical offsets are checked. IDs are ordered
uint64 original IDs. Sample offsets have S+1 entries indexing trees; tree offsets
have T+1 entries indexing nodes. Each node is 32 bytes: int32 feature, left, right;
uint32 kind; binary64 threshold, leaf value. Child IDs are local to each tree.
Leaves use kind=0, feature/children=-1; splits use kind=1. Only reachable nodes
are stored in preorder. Children follow parents and have exactly one parent,
which proves acyclicity and reachability. Conversion follows the actual source
children, even when training prune/grow has recycled non-monotone node IDs.

Metadata is UTF-8 JSON: exact producer fields except the bulky forest object,
source compressed-artifact SHA-256, reference fork, feature order, original
sample mapping and explicit converter scope. Original IDs are independently
checked against embedded compaction metadata; compact positions are never
relabelled as original IDs. Producer version is not rewritten as converter or
serving-engine identity. Converter/core/compiler hashes belong in run receipts.

CRC detects corruption, not adversarial authenticity. The caller must verify
the immutable artifact SHA-256 and provenance before opening it. Limits default
to 2 GiB files, 64 million nodes and 16 MiB metadata; malformed sizes/offsets,
unsupported flags, invalid features, cycles and truncated files fail. The reader
currently holds a checked byte buffer plus decoded nodes temporarily; it is not
mmap or zero-copy. This memory is included in process peak measurements.

The writer uses an exclusive staging directory, checks the complete written file
through the reader, and commits through a no-replacement hard link. Failed writes
remove only their owned staging directory; existing artifacts are never replaced.
The prototype assumes a local filesystem supporting hard links. Durable fsync and
cross-platform publication semantics require separate production integration.

## Validation and measurement

`test.cpp`: thresholds and adjacent binary64 values, NaN/infinities, reordered and
repeated samples, mapped vs fixed, bad bounds/IDs/nodes, corruption, truncation,
replacement refusal and repeated handle destruction. Run with ASan/UBSan.
`test_converter.py`: recycled/deleted nodes, unsupported capabilities, source
identity checks and malformed files with correctly recomputed CRCs.
`structural.py`: independent byte comparison of every retained reachable source
node with the packed representation. Real CT/CMA probes compare standalone and
R-adapter raw values, mapped values and unchanged scaled/RFX latent values exactly.

Benchmark all-sample and selected-sample binaries separately, against the same
compressed source and same preprocessed inputs. This separates binary loading
benefit from retained-sample compaction. Warm/uncontrolled local results do not
qualify deployment capacity, cloud transfer cost, full-scenario latency, the
parent working set, or other architectures. The provisional gates are 2x faster
complete load+selected raw prediction and 50% lower fresh-process peak. Preserve
the baseline's seeds, pairing and immutable source artifacts.
