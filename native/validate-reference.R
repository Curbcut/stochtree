# Adapter-only process, separate from the legacy namespace.
args<-commandArgs(TRUE);stopifnot(length(args)==1L)
root<-normalizePath(args[[1]],mustWork=TRUE)
ref<-readRDS(file.path(root,"reference.rds"))
h<-nashtree:::ntf_open(file.path(root,"forest.ntf"))
raw<-nashtree:::ntf_predict_fixed(h,ref$x,ref$ids)
mapped<-nashtree:::ntf_predict_mapped(h,ref$x,ref$mapped_ids)
stopifnot(identical(as.double(raw),as.double(ref$raw)),identical(mapped,as.double(ref$mapped)))
con<-file(file.path(root,"standalone.bin"),"rb");standalone<-readBin(con,"double",n=length(raw),size=8,endian="little");close(con)
con<-file(file.path(root,"standalone-mapped.bin"),"rb");standalone_mapped<-readBin(con,"double",n=length(mapped),size=8,endian="little");close(con)
stopifnot(identical(as.double(raw),standalone),identical(mapped,standalone_mapped))
latent<-raw*ref$scale+ref$mean
if(!is.null(ref$rfx))latent<-latent+ref$rfx
stopifnot(identical(as.double(latent),as.double(ref$latent)))
# Caller order and repeated IDs, empty rows, invalid IDs, explicit close.
stopifnot(identical(nashtree:::ntf_predict_fixed(h,ref$x,rev(ref$ids)),raw[,rev(seq_along(ref$ids)),drop=FALSE]))
stopifnot(nrow(nashtree:::ntf_predict_fixed(h,ref$x[FALSE,,drop=FALSE],ref$ids))==0L)
stopifnot(inherits(try(nashtree:::ntf_predict_fixed(h,ref$x,NA_real_),silent=TRUE),"try-error"))
nashtree:::ntf_close(h)
stopifnot(inherits(try(nashtree:::ntf_metadata(h),silent=TRUE),"try-error"))
jsonlite::write_json(list(adapter_raw_bitwise=TRUE,standalone_raw_bitwise=TRUE,mapped_bitwise=TRUE,
 legacy_scaled_random_effect_latent_bitwise=TRUE,scope="component equivalence; no full system qualification",
 binary_sha256=digest::digest(file=file.path(root,"forest.ntf"),algo="sha256")),
 file.path(root,"equivalence.json"),auto_unbox=TRUE,pretty=TRUE)
