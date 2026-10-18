# Separate distribution experiment; never overwrite an input or old evidence.
args<-commandArgs(TRUE);stopifnot(length(args)==2L)
input<-normalizePath(args[[1]],mustWork=TRUE);output<-args[[2]]
stopifnot(!dir.exists(output));dir.create(output,recursive=TRUE)
results<-list()
for(variant in c("forest.ntf","forest-all.ntf")) {
 source<-file.path(input,variant);packed<-file.path(output,paste0(variant,".zst"));restored<-file.path(output,paste0(variant,".restored"))
 start<-proc.time()[["elapsed"]];qs2::zstd_compress_file(source,packed,compress_level=3L);compressed<-proc.time()[["elapsed"]]
 qs2::zstd_decompress_file(packed,restored,max_output_bytes=file.info(source)$size);done<-proc.time()[["elapsed"]]
 sha<-function(path)digest::digest(file=path,algo="sha256")
 stopifnot(identical(sha(source),sha(restored)))
 results[[variant]]<-list(local_bytes=file.info(source)$size,compressed_bytes=file.info(packed)$size,
 compression_seconds=compressed-start,decompression_seconds=done-compressed,roundtrip_SHA256_exact=TRUE)
}
jsonlite::write_json(list(qs2=as.character(packageVersion("qs2")),level=3,cache_state="local warm/uncontrolled",
 results=results),file.path(output,"distribution.json"),auto_unbox=TRUE,pretty=TRUE,digits=NA)
