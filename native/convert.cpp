#include "nashtree/inference.h"
#include <nlohmann/json.hpp>
#include <algorithm>
#include <fstream>
#include <filesystem>
#include <functional>
#include <iostream>
#include <set>
#include <stdexcept>
using json=nlohmann::json;
using nashtree::Forest;
void check(bool ok,const char* msg) { if(!ok) throw std::runtime_error(msg); }
int main(int argc,char** argv) {
 try {
  check(argc==4,"usage: ntf-convert model.json plan.json output.ntf");
  check(std::filesystem::file_size(argv[1])<=2147483648ULL && std::filesystem::file_size(argv[2])<=16777216ULL,"conversion input size limit");
  std::ifstream input(argv[1]),plan_file(argv[2]); json model,plan; input>>model;plan_file>>plan;
  check(model.at("include_mean_forest").get<bool>() && !model.at("include_variance_forest").get<bool>() &&
        !model.at("requires_basis").get<bool>() && !model.at("probit_outcome_model").get<bool>() &&
        model.at("num_forests")==1 && model.at("outcome_model").at("link")=="identity" &&
        model.at("outcome_model").at("outcome")=="continuous","unsupported model capability; use legacy backend");
  const auto& container=model.at("forests").at("forest_0");
  check(container.at("output_dimension")==1 && container.at("is_leaf_constant").get<bool>() &&
        !container.at("is_exponentiated").get<bool>() && container.at("initialized").get<bool>(),"unsupported forest capability");
  Forest out; out.features=model.at("num_covariates").get<std::uint64_t>();
  out.original_samples=plan.at("original_samples").get<std::uint64_t>();
  check(plan.at("feature_names").size()==out.features,"feature order metadata missing");
  const auto sha=plan.at("source_sha256").get<std::string>();
  check(sha.size()==64 && sha.find_first_not_of("0123456789abcdef")==std::string::npos,"source SHA-256 required");
  auto positions=plan.at("positions").get<std::vector<std::uint64_t>>();
  out.sample_ids=plan.at("original_ids").get<std::vector<std::uint64_t>>();
  check(positions.size()==out.sample_ids.size() && !positions.empty(),"sample selection mismatch");
  check(std::set<std::uint64_t>(positions.begin(),positions.end()).size()==positions.size(),"duplicate source positions");
  const auto count=container.at("num_samples").get<std::uint64_t>();
  const auto trees=container.at("num_trees").get<std::uint64_t>();
  const bool compact=model.contains("_nash_compact_original_num_samples");
  check(out.original_samples==(compact?model.at("_nash_compact_original_num_samples").get<std::uint64_t>():count),"original sample count does not match producer metadata");
  for(std::size_t s=0;s<positions.size();++s) {
    check(positions[s]<count,"source sample out of range");
    const auto original=compact?model.at("_nash_compact_retained_original_ids").at(positions[s]).get<std::uint64_t>():positions[s];
    check(out.sample_ids[s]==original,"original sample identity does not match source position");
  }
  out.sample_trees.push_back(0);out.tree_nodes.push_back(0);
  for(std::size_t s=0;s<positions.size();++s) {
   check(positions[s]<count,"source sample out of range");
   const auto& sample=container.at("forest_"+std::to_string(positions[s]));
   check(sample.at("num_trees")==trees && sample.at("output_dimension")==1 &&
     sample.at("is_leaf_constant").get<bool>() && !sample.at("is_exponentiated").get<bool>(),"inconsistent sample capability");
   for(std::uint64_t t=0;t<trees;++t) {
    const auto& tree=sample.at("tree_"+std::to_string(t));
    const auto n=tree.at("num_nodes").get<std::size_t>();
    check(n>0 && n<=INT32_MAX && tree.at("output_dimension")==1 && !tree.at("is_log_scale").get<bool>() &&
      !tree.at("has_categorical_split").get<bool>(),"unsupported tree capability");
    for(const char* field:{"node_type","node_deleted","left","right","split_index","threshold","leaf_value"})
      check(tree.at(field).size()==n,"source node array length mismatch");
    const auto begin=out.nodes.size();std::vector<unsigned char> visited(n,0);
    std::function<std::int32_t(std::int32_t,std::size_t)> visit=[&](std::int32_t old,std::size_t depth) {
      check(old>=0 && std::size_t(old)<n && depth<4096,"invalid source child or excessive depth");
      check(!visited[old] && !tree.at("node_deleted").at(old).get<bool>(),"cyclic, shared or deleted reachable source node");
      visited[old]=1;
      const auto at=out.nodes.size();const auto local=static_cast<std::int32_t>(at-begin);
      const auto kind=tree.at("node_type").at(old).get<std::uint32_t>();
      check(kind<=1,"unsupported categorical or unknown split");
      out.nodes.push_back({-1,-1,-1,kind,0,0});
      if(kind==0) out.nodes[at].value=tree.at("leaf_value").at(old).get<double>();
      else {
        out.nodes[at].feature=tree.at("split_index").at(old).get<std::int32_t>();
        out.nodes[at].threshold=tree.at("threshold").at(old).get<double>();
        const auto left=visit(tree.at("left").at(old).get<std::int32_t>(),depth+1);
        const auto right=visit(tree.at("right").at(old).get<std::int32_t>(),depth+1);
        out.nodes[at].left=left;out.nodes[at].right=right;
      }
      return local;
    };
    visit(0,0);out.tree_nodes.push_back(out.nodes.size());
   }
   out.sample_trees.push_back(out.tree_nodes.size()-1);
  }
  // Preserve producer metadata verbatim. Converter and runtime are distinct identities.
  model.erase("forests");
  out.metadata=json{{"scope","raw_mean_forest_only"},{"converter_format","nashtree_forest_v1"},
    {"plan",plan},{"producer_metadata",model},{"legacy_random_effects_required",model.at("has_rfx")}}.dump();
  out.save(argv[3]);
  std::cout<<json{{"samples",out.sample_ids.size()},{"trees",out.tree_nodes.size()-1},{"nodes",out.nodes.size()},
    {"features",out.features},{"metadata_bytes",out.metadata.size()}}.dump()<<"\n";
  return 0;
 } catch(const std::exception& e) { std::cerr<<e.what()<<"\n";return 1; }
}
