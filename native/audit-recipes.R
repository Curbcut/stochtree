# Bounded read-only audit of package references in real serialized R recipes.
args<-commandArgs(TRUE);stopifnot(length(args)==2L)
root<-normalizePath(args[[1]],mustWork=TRUE);out<-args[[2]]
stopifnot(!file.exists(out));results<-list()
for(name in c("ct_level","ct_change","cma")) {
 path<-file.path(root,name,"recipe.qdata");recipe<-qs2::qd_read(path)
 findings<-list();visited<-0L;truncated<-FALSE
 walk<-function(x,key,depth=0L) {
  visited<<-visited+1L
  if(visited>100000L||depth>30L){truncated<<-TRUE;return(invisible(NULL))}
  if(is.environment(x)||is.function(x)||typeof(x)=="externalptr") {
   findings[[length(findings)+1L]]<<-list(path=key,type=typeof(x),class=class(x),
    environment=if(is.function(x))environmentName(environment(x))else if(is.environment(x))environmentName(x)else NULL)
  } else if(is.list(x)) {
   for(i in seq_along(x))walk(x[[i]],paste0(key,"/",if(is.null(names(x)))i else names(x)[i]),depth+1L)
  } else if(is.character(x)&&any(grepl("^stochtree(::|$)",x))) {
   findings[[length(findings)+1L]]<<-list(path=key,type="package_string",values=x[grepl("^stochtree(::|$)",x)])
  }
  if(!is.environment(x)&&!is.function(x)&&length(attributes(x))) {
   for(a in names(attributes(x)))walk(attr(x,a,exact=TRUE),paste0(key,"/@",a),depth+1L)
  }
  invisible(NULL)
 }
 walk(recipe,"recipe")
 results[[name]]<-list(source_sha256=digest::digest(file=path,algo="sha256"),visited=visited,truncated=truncated,package_or_opaque_references=findings)
}
jsonlite::write_json(list(scope="Three representative serialized recipes; not a full historical R-object compatibility audit",results=results),out,auto_unbox=TRUE,pretty=TRUE,null="null")
