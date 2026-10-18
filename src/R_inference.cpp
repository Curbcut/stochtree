#include <cpp11.hpp>
#include "include/nashtree/inference.h"
#include <cmath>
#include <climits>
#include <stdexcept>
namespace {
std::vector<std::uint64_t> native_ids(cpp11::doubles ids) {
  std::vector<std::uint64_t> out;out.reserve(ids.size());
  for(auto id:ids) {
    if(!std::isfinite(id)||id<0||id>9007199254740991.0||std::floor(id)!=id) cpp11::stop("invalid sample ID");
    out.push_back(static_cast<std::uint64_t>(id));
  }
  return out;
}
void require_open(cpp11::external_pointer<nashtree::Forest> ptr) {
  if(!ptr.get()) cpp11::stop("forest handle is closed");
}
}
[[cpp11::register]]
cpp11::external_pointer<nashtree::Forest> inference_open_cpp(std::string path) {
  return cpp11::external_pointer<nashtree::Forest>(new nashtree::Forest(nashtree::Forest::load(path)));
}
[[cpp11::register]]
void inference_close_cpp(cpp11::external_pointer<nashtree::Forest> ptr) { ptr.reset(); }
[[cpp11::register]]
std::string inference_metadata_cpp(cpp11::external_pointer<nashtree::Forest> ptr) {
  require_open(ptr);return ptr->metadata;
}
[[cpp11::register]]
cpp11::writable::doubles_matrix<> inference_fixed_cpp(cpp11::external_pointer<nashtree::Forest> ptr,
  cpp11::doubles_matrix<> x,cpp11::doubles ids) {
  require_open(ptr);auto selected=native_ids(ids);
  if(ids.size()>INT_MAX) cpp11::stop("too many selected samples");
  cpp11::writable::doubles_matrix<> out(x.nrow(),ids.size());
  ptr->predict_fixed({REAL(x),std::size_t(x.nrow()),std::size_t(x.ncol()),1,std::size_t(x.nrow()),std::size_t(x.size())},
    selected,REAL(out),out.size());return out;
}
[[cpp11::register]]
cpp11::writable::doubles inference_mapped_cpp(cpp11::external_pointer<nashtree::Forest> ptr,
  cpp11::doubles_matrix<> x,cpp11::doubles ids) {
  require_open(ptr);auto selected=native_ids(ids);cpp11::writable::doubles out(x.nrow());
  ptr->predict_mapped({REAL(x),std::size_t(x.nrow()),std::size_t(x.ncol()),1,std::size_t(x.nrow()),std::size_t(x.size())},
    selected,REAL(out),out.size());return out;
}
