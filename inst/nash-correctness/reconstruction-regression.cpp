#include <stochtree/partition_tracker.h>
#include <stochtree/tree.h>
#include <algorithm>
#include <iostream>
using namespace StochTree;
int check(Tree& t,FeatureUnsortedPartition& p,ForestDataset& d) {
 int failures=0;
 for(int id=0;id<t.NumNodes();++id)if(!t.IsDeleted(id)){
  if(p.Parent(id)!=t.Parent(id)||p.LeftNode(id)!=t.LeftChild(id)||p.RightNode(id)!=t.RightChild(id))++failures;
  if(t.IsLeaf(id)){
   std::vector<int> expected;for(int i=0;i<d.NumObservations();++i)if(EvaluateTree(t,d.GetCovariates(),i)==id)expected.push_back(i);
   auto actual=p.NodeIndices(id);std::sort(actual.begin(),actual.end());if(actual!=expected)++failures;
  }
 }
 return failures;
}
int main(){
 int failures=0;
 for(bool categorical:{false,true}){
  double x[]={0,1,2,3,4,5,6,7,8,9,10,11};ForestDataset d;d.AddCovariates(x,12,1,true);Tree t;t.Init();
  auto split=[&](int id,int threshold){if(categorical){std::vector<uint32_t> cat;for(int i=0;i<=threshold;++i)cat.push_back(i);t.ExpandNode(id,0,cat,0.,0.);}else t.ExpandNode(id,0,threshold+.5,0.,0.);};
  split(0,5);split(1,2);split(2,8);t.ChangeToLeaf(1,0.);split(5,7);int reused=t.LeftChild(5);split(reused,6);
  FeatureUnsortedPartition p(12);p.ReconstituteFromTree(t,d);failures+=check(t,p,d);
  // Continue pruning and growing after reconstruction, including reused IDs.
  p.PruneNodeToLeaf(reused);t.ChangeToLeaf(reused,0.);failures+=check(t,p,d);
  split(reused,6);
  if(categorical)p.PartitionNode(d.GetCovariates(),reused,t.LeftChild(reused),t.RightChild(reused),0,std::vector<uint32_t>{0,1,2,3,4,5,6});
  else p.PartitionNode(d.GetCovariates(),reused,t.LeftChild(reused),t.RightChild(reused),0,6.5);
  failures+=check(t,p,d);
  FeatureUnsortedPartition again(12);again.ReconstituteFromTree(t,d);failures+=check(t,again,d);
 }
 std::cout<<"Numerical/categorical recycled-ID reconstruction and continued prune/grow failures: "<<failures<<"\n";return failures?1:0;
}
