# Paired raw-forest boundary. Inputs are already preprocessed for BOTH engines.
# Excludes original R recipe/RFX work, conversion and output writing; includes load,
# integrity checking and selected prediction. Run in separate fresh processes.
args<-commandArgs(TRUE);stopifnot(length(args)==4L)
mode<-args[[1]];root<-args[[2]];forest<-args[[3]];output<-args[[4]]
ref<-readRDS(file.path(root,"reference.rds"))
# Common application namespace/dependencies preloaded in both fresh processes.
loadNamespace("nash")
loadNamespace(if(mode=="legacy") "stochtree" else "nashtree")
start<-proc.time()[["elapsed"]]
if(mode=="legacy") {
 model<-nash:::nash_st_load_model(forest)
 loaded<-proc.time()[["elapsed"]]
 data<-stochtree::createForestDataset(ref$x)
 raw<-as.matrix(model$mean_forests$predict(data))
 map<-model[["nash_compact_sample_map",exact=TRUE]]
 ids<-if(is.null(map))ref$ids else match(ref$ids,map$retained_original_ids)-1L
 result<-raw[,ids+1L,drop=FALSE]
} else {
 h<-nashtree:::ntf_open(forest)
 loaded<-proc.time()[["elapsed"]]
 result<-nashtree:::ntf_predict_fixed(h,ref$x,ref$ids)
}
end<-proc.time()[["elapsed"]]
stopifnot(identical(as.double(result),as.double(ref$raw)))
engine <- if(mode=="legacy")"stochtree" else "nashtree"
native_path <- system.file("libs",paste0(engine,.Platform$dynlib.ext),package=engine)
stopifnot(nzchar(native_path))
jsonlite::write_json(list(native_library_sha256=digest::digest(file=native_path,algo="sha256"),
 source_commit=Sys.getenv("NASHTREE_SOURCE_COMMIT"),nash_code_hash=nash:::nash_runner_code_hash(),
 mode=mode,load_seconds=loaded-start,selected_prediction_seconds=end-loaded,
 load_predict_seconds=end-start,exact=TRUE,R=R.version.string,
 boundary="preprocessed input to selected raw mean-forest outputs",artifact_sha256=digest::digest(file=forest,algo="sha256")),
 output,auto_unbox=TRUE,pretty=TRUE,digits=NA)
