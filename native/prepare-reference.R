# Legacy-only process. Export numeric inputs and exact raw/latent references.
args <- commandArgs(TRUE)
stopifnot(length(args) == 2L)
source_dir <- normalizePath(args[[1]], mustWork = TRUE)
out <- args[[2]]
stopifnot(!dir.exists(out))
dir.create(out, recursive = TRUE)
source <- jsonlite::read_json(file.path(source_dir, "source.json"), simplifyVector = TRUE)
forest <- file.path(source_dir, "forest.json.zst")
sha <- digest::digest(file = forest, algo = "sha256")
stopifnot(identical(sha, source$sha256))
probe <- readRDS(file.path(source_dir, "probe.rds"))
legacy <- readRDS(file.path(source_dir, "draws.rds"))
model <- nash:::nash_st_load_model(forest)
processed <- stochtree::preprocessPredictionData(as.data.frame(probe$x), model$train_set_metadata)
stopifnot(is.matrix(processed), is.numeric(processed))
compact <- model[["nash_compact_sample_map",exact=TRUE]]
count <- model$mean_forests$num_samples()
all_ids <- if (is.null(compact)) NULL else compact$retained_original_ids
if (is.null(all_ids)) all_ids <- seq_len(count) - 1L
# Inspect actual compact map convention before permitting conversion.
if (is.list(all_ids)) stop("Unsupported compact map metadata; explicit migration required")
if (length(all_ids) != count) stop("Compact map length mismatch")
positions <- sort(unique(probe$path_map))
original_ids <- as.integer(all_ids[positions + 1L])
stopifnot(!anyNA(original_ids), !is.unsorted(original_ids, strictly = TRUE))
original_count <- if (is.null(compact)) count else compact$original_num_samples
raw <- as.matrix(model$mean_forests$predict(stochtree::createForestDataset(processed)))
selected <- raw[, probe$path_map + 1L, drop = FALSE]
latent <- nash:::nash_st_predict_fixed_horizon_paths(model, probe$x, probe$path_map,
  draw_type = "latent", rfx_group_ids = probe$groups)
stopifnot(identical(latent, legacy))
rfx <- nash:::nash_st_rfx_term(model, as.data.frame(probe$x), probe$groups)
plan <- list(source_sha256 = sha, original_samples = original_count,
  positions = positions, original_ids = original_ids,
  source_original_ids = all_ids,
  feature_names = if (is.null(colnames(processed))) paste0("column_", seq_len(ncol(processed))) else colnames(processed),
  recipe_scope = "Legacy R preprocessing and outcome/rfx semantics retained",
  fork_sha = "0ac0e7d091556d3dd1b8102ac4a010805cad55d1")
jsonlite::write_json(plan, file.path(out,"plan.json"), auto_unbox=TRUE, pretty=TRUE, digits=NA)
con<-file(file.path(out,"x.bin"),"wb");writeBin(as.double(t(processed)),con,size=8,endian="little");close(con)
writeLines(as.character(all_ids[probe$path_map+1L]),file.path(out,"ids.txt"))
# One varying sample per row exercises mapped evaluation without a cross product.
mapped_positions <- rep(probe$path_map,length.out=nrow(processed))
mapped <- raw[cbind(seq_len(nrow(processed)),mapped_positions+1L)]
writeLines(as.character(all_ids[mapped_positions+1L]),file.path(out,"mapped-ids.txt"))
saveRDS(list(x=processed,ids=all_ids[probe$path_map+1L],mapped_ids=all_ids[mapped_positions+1L],
 raw=selected,mapped=mapped,latent=latent,rfx=if(is.null(rfx))NULL else rfx[,probe$path_map+1L,drop=FALSE],
 scale=model$model_params$outcome_scale,mean=model$model_params$outcome_mean),file.path(out,"reference.rds"),version=3)
jsonlite::write_json(list(rows=nrow(processed),columns=ncol(processed),draws=ncol(selected),
 source_sha256=sha,source_probe_sha256=digest::digest(file=file.path(source_dir,"probe.rds"),algo="sha256"),
 source_draws_sha256=digest::digest(file=file.path(source_dir,"draws.rds"),algo="sha256"),
 nash=as.character(packageVersion("nash")),stochtree=as.character(packageVersion("stochtree")),
 R=R.version.string, legacy_latent_exact=TRUE),file.path(out,"receipt.json"),auto_unbox=TRUE,pretty=TRUE)
qs2::zstd_decompress_file(forest,file.path(out,"model.json"))
