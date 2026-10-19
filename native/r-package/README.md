# Inference-only R bindings

`Rscript native/r-package/build.R /new/source/directory [exact-source-commit]`
creates `nashtreeInference` from this checkout's **same** core, thin bindings and
existing generated registration. It contains no training code, S3 methods,
random-number generation or duplicate evaluator. Use a clean pinned checkout;
archive-based builders must supply the exact 40-character source commit.
The package records that commit and SHA-256 of every copied/generated input.
Install into a new library with `R CMD INSTALL --library=/new/library /new/source/directory`.

This permits the historical stochtree namespace to remain loaded. Loading the
full nashtree training package beside stochtree still has colliding S3 classes;
that combination remains unsupported. There is no model-class migration.
Native v1 files and core numerical order are unchanged. A different package/DLL
identity invalidates conversion cache reuse and requires new runtime evidence.

Validation: build/install the small package, load stochtree first and second in
separate processes, assert identical registered historical methods, and run the
Nash slice-F fixed/streamed/legacy/deferred/corruption checks. These bounded
checks do not qualify an image, a complete scenario or production use.

Loaded producer conversion can now pass plain preorder node/offset arrays to
`ntf_write()`. The producer traverses its own handle; no training pointer is
reinterpreted across library boundaries. The writer validates dimensions,
original IDs, topology, leaf/split types and byte/node limits, then uses the same
native v1 serializer and strict readback. Existing files are never replaced.
`ntf_sync()` supplies explicit file/directory synchronization for local POSIX
cache commits. Unsupported platforms fail rather than pretending to provide a
durability guarantee. Publication and automatic retention are separate policies.
