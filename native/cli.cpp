#include "nashtree/inference.h"
#include <chrono>
#include <fstream>
#include <filesystem>
#include <iostream>
#include <stdexcept>
#include <string>
// Input is little-endian IEEE754 doubles in row-major order. IDs are decimal text.
int main(int argc,char** argv) {
 try {
  if(argc!=9) throw std::runtime_error("usage: ntf-predict forest.ntf fixed|mapped rows columns x.bin ids.txt output.bin repeats");
  const auto start=std::chrono::steady_clock::now();
  auto forest=nashtree::Forest::load(argv[1]);
  const auto loaded=std::chrono::steady_clock::now();
  const auto rows=std::stoull(argv[3]), cols=std::stoull(argv[4]), repeats=std::stoull(argv[8]);
  if(cols!=forest.features || rows>1000000 || repeats==0 || repeats>10000 || rows>SIZE_MAX/cols) throw std::runtime_error("input size limits");
  if(rows*cols>268435456 || std::filesystem::file_size(argv[5])!=rows*cols*8) throw std::runtime_error("input byte limit or length mismatch");
  std::vector<double> x(rows*cols);std::ifstream input(argv[5],std::ios::binary);
  if(!input.read(reinterpret_cast<char*>(x.data()),x.size()*8) || input.peek()!=EOF) throw std::runtime_error("input length mismatch");
  const std::uint16_t endian=1;
  if(*reinterpret_cast<const unsigned char*>(&endian)!=1) throw std::runtime_error("CLI input requires little endian");
  std::ifstream idfile(argv[6]);std::vector<std::uint64_t> ids;std::string token;
  while(idfile>>token) {
    if(token.empty() || token.find_first_not_of("0123456789")!=std::string::npos) throw std::runtime_error("invalid sample ID");
    ids.push_back(std::stoull(token));
  }
  if(!idfile.eof() || ids.size()>1000000) throw std::runtime_error("invalid IDs file");
  const bool fixed=std::string(argv[2])=="fixed";
  if(!fixed && std::string(argv[2])!="mapped") throw std::runtime_error("unknown prediction operation");
  if(fixed && rows && ids.size()>SIZE_MAX/rows) throw std::runtime_error("output overflow");
  const auto count=fixed?rows*ids.size():rows;
  if(count>268435456) throw std::runtime_error("output byte limit");
  std::vector<double> output(count);
  nashtree::MatrixView view{x.data(),std::size_t(rows),std::size_t(cols),std::size_t(cols),1,x.size()};
  const auto ready=std::chrono::steady_clock::now();
  for(std::uint64_t r=0;r<repeats;++r) {
    if(fixed) forest.predict_fixed(view,ids,output.data(),output.size());
    else forest.predict_mapped(view,ids,output.data(),output.size());
  }
  const auto done=std::chrono::steady_clock::now();
  std::ofstream out(argv[7],std::ios::binary);
  if(!out.write(reinterpret_cast<const char*>(output.data()),output.size()*8)) throw std::runtime_error("output write failed");
  auto seconds=[](auto a,auto b){return std::chrono::duration<double>(b-a).count();};
  std::cout<<"{\"load_seconds\":"<<seconds(start,loaded)<<",\"input_seconds\":"<<seconds(loaded,ready)
    <<",\"prediction_seconds\":"<<seconds(ready,done)<<",\"repeats\":"<<repeats<<",\"nodes\":"<<forest.nodes.size()<<"}\n";
 } catch(const std::exception& e) {std::cerr<<e.what()<<"\n";return 1;}
}
