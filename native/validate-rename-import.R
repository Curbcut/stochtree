# Renamed legacy importer vs previously prepared source-engine raw references.
args<-commandArgs(TRUE);stopifnot(length(args)==1L)
d<-args[[1]];ref<-readRDS(file.path(d,"reference.rds"))
j<-nashtree::createCppJsonFile(file.path(d,"model.json"))
m<-nashtree::createBARTModelFromJson(j)
all<-as.matrix(m$mean_forests$predict(nashtree::createForestDataset(ref$x)))
plan<-jsonlite::read_json(file.path(d,"plan.json"),simplifyVector=TRUE)
positions<-match(ref$ids,plan$source_original_ids)-1L
stopifnot(!anyNA(positions),identical(as.double(all[,positions+1L,drop=FALSE]),as.double(ref$raw)))
jsonlite::write_json(list(historical_import_raw_bitwise=TRUE,source_sha256=plan$source_sha256),
 file.path(d,"rename-import.json"),auto_unbox=TRUE,pretty=TRUE)
