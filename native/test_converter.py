#!/usr/bin/env python3
import copy, json, pathlib, struct, subprocess, sys, tempfile, unittest
BUILD=pathlib.Path(sys.argv[1]).resolve();sys.argv=sys.argv[:1]
def tree():
 # Recycled IDs: root -> left 4/right 1; deleted nodes 2,3 must disappear.
 return dict(num_nodes=5,output_dimension=1,is_log_scale=False,has_categorical_split=False,
  node_type=[1,0,0,0,0],node_deleted=[False,False,True,True,False],
  left=[4,-1,-1,-1,-1],right=[1,-1,-1,-1,-1],split_index=[0,-1,-1,-1,-1],
  threshold=[0.5,0,0,0,0],leaf_value=[0,2,99,99,1])
def model():
 sample=dict(num_trees=1,output_dimension=1,is_leaf_constant=True,is_exponentiated=False,tree_0=tree())
 container=dict(num_samples=1,num_trees=1,output_dimension=1,is_leaf_constant=True,is_exponentiated=False,initialized=True,forest_0=sample)
 return dict(include_mean_forest=True,include_variance_forest=False,requires_basis=False,probit_outcome_model=False,
  num_forests=1,num_covariates=1,has_rfx=False,outcome_model=dict(link="identity",outcome="continuous"),
  _nash_compact_original_num_samples=8,_nash_compact_retained_original_ids=[3],forests=dict(forest_0=container))
def plan():return dict(original_samples=8,positions=[0],original_ids=[3],feature_names=['x'],source_sha256='a'*64)
def crc(data):
 v=0
 for b in data:
  v^=b<<56
  for _ in range(8):v=((v<<1)^ (0x42F0E1EBA9EA3693 if v>>63 else 0))&0xffffffffffffffff
 return v
class Conversion(unittest.TestCase):
 def setUp(self):self.tmp=tempfile.TemporaryDirectory();self.d=pathlib.Path(self.tmp.name)
 def tearDown(self):self.tmp.cleanup()
 def convert(self,m=None,p=None,name='result.ntf'):
  (self.d/'model.json').write_text(json.dumps(model() if m is None else m));(self.d/'plan.json').write_text(json.dumps(plan() if p is None else p))
  return subprocess.run([str(BUILD/'ntf-convert'),str(self.d/'model.json'),str(self.d/'plan.json'),str(self.d/name)],capture_output=True,text=True)
 def test_recycled_ids_and_exact_nodes(self):
  r=self.convert();self.assertEqual(r.returncode,0,r.stderr)
  b=(self.d/'result.ntf').read_bytes();self.assertEqual(struct.unpack_from('<Q',b,48)[0],3)
  no=struct.unpack_from('<Q',b,112)[0]
  self.assertEqual(struct.unpack_from('<iiiIdd',b,no),(0,1,2,1,0.5,0))
  self.assertEqual(struct.unpack_from('<d',b,no+32+24)[0],1)
  self.assertEqual(struct.unpack_from('<d',b,no+64+24)[0],2)
  self.assertNotEqual(self.convert().returncode,0)
 def test_unsupported_and_malformed_source(self):
  for key,value in [('include_variance_forest',True),('requires_basis',True),('probit_outcome_model',True),('num_forests',2)]:
   m=model();m[key]=value;self.assertNotEqual(self.convert(m).returncode,0,key)
  for field,value in [('output_dimension',2),('has_categorical_split',True),('is_log_scale',True)]:
   m=model();m['forests']['forest_0']['forest_0']['tree_0'][field]=value;self.assertNotEqual(self.convert(m).returncode,0,field)
  for left in [0,1,2,5,-1]:
   m=model();m['forests']['forest_0']['forest_0']['tree_0']['left'][0]=left;self.assertNotEqual(self.convert(m).returncode,0,str(left))
 def test_plan_indices(self):
  for field,value in [('original_ids',[8]),('positions',[1]),('positions',[0,0]),('feature_names',[]),('source_sha256','wrong')]:
   p=plan();p[field]=value;self.assertNotEqual(self.convert(p=p).returncode,0,field)
 def test_structural_corruption_after_valid_crc(self):
  self.assertEqual(self.convert().returncode,0)
  source=(self.d/'result.ntf').read_bytes();no=struct.unpack_from('<Q',source,112)[0]
  # Invalid node kind, feature, cyclic child, header dimension, length and offset.
  for offset,fmt,value in [(no+12,'I',2),(no,'i',1),(no+4,'i',0),(64,'Q',0),(24,'Q',2),(112,'Q',128)]:
   b=bytearray(source);struct.pack_into('<'+fmt,b,offset,value);struct.pack_into('<Q',b,80,0);struct.pack_into('<Q',b,80,crc(b))
   (self.d/'bad.ntf').write_bytes(b)
   (self.d/'x').write_bytes(struct.pack('<d',0));(self.d/'ids').write_text('3\n')
   r=subprocess.run([str(BUILD/'ntf-predict'),str(self.d/'bad.ntf'),'fixed','1','1',str(self.d/'x'),str(self.d/'ids'),str(self.d/'out'),'1'],capture_output=True,text=True)
   self.assertNotEqual(r.returncode,0,str(offset))
if __name__=='__main__':unittest.main()
