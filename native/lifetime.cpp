#include "nashtree/inference.h"
#include <sys/resource.h>
#include <iostream>
#include <stdexcept>
int main(int argc,char** argv) {
 try {
  if(argc!=2)throw std::runtime_error("usage: ntf-lifetime forest.ntf");
  std::cout<<"[";
  for(int i=0;i<30;++i) {
   {auto forest=nashtree::Forest::load(argv[1]);forest.validate();}
   struct rusage use{};if(getrusage(RUSAGE_SELF,&use)!=0)throw std::runtime_error("rusage failed");
#ifdef __APPLE__
   const auto peak=use.ru_maxrss;
#else
   const auto peak=use.ru_maxrss*1024;
#endif
   if(i)std::cout<<",";std::cout<<peak;
  }
  std::cout<<"]\n";
 }catch(const std::exception& e){std::cerr<<e.what()<<"\n";return 1;}
}
