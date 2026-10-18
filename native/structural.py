#!/usr/bin/env python3
"""Independent structural audit: original reachable JSON nodes vs packed binary64."""
import argparse, json, struct, pathlib, math
p=argparse.ArgumentParser();p.add_argument('directory',type=pathlib.Path);p.add_argument('--all',action='store_true');a=p.parse_args();d=a.directory
suffix='-all' if a.all else ''
plan=json.loads((d/f'plan{suffix}.json').read_text());source=json.loads((d/'model.json').read_text());b=(d/f'forest{suffix}.ntf').read_bytes()
ns,nt,nn,nm=struct.unpack_from('<4Q',b,32);io,so,to,no,mo=struct.unpack_from('<5Q',b,88)
ids=struct.unpack_from(f'<{ns}Q',b,io);samples=struct.unpack_from(f'<{ns+1}Q',b,so);trees=struct.unpack_from(f'<{nt+1}Q',b,to)
assert list(ids)==plan['original_ids']
checked=0
for s,pos in enumerate(plan['positions']):
 f=source['forests']['forest_0'][f'forest_{pos}']
 assert samples[s+1]-samples[s]==f['num_trees']
 for t in range(f['num_trees']):
  j=f[f'tree_{t}'];tree_index=samples[s]+t;start=trees[tree_index];expected=[]
  def walk(old):
   at=len(expected);expected.append(None);kind=j['node_type'][old]
   assert not j['node_deleted'][old]
   if kind==0: expected[at]=(-1,-1,-1,0,0.0,j['leaf_value'][old])
   else:
    assert kind==1
    left=walk(j['left'][old]);right=walk(j['right'][old])
    expected[at]=(j['split_index'][old],left,right,1,j['threshold'][old],0.0)
   return at
  walk(0)
  assert len(expected)==trees[tree_index+1]-start
  for i,node in enumerate(expected):
   # Binary pack comparison preserves signed zeros and binary64 values exactly.
   assert struct.pack('<iiiIdd',*node)==b[no+32*(start+i):no+32*(start+i+1)]
  checked+=len(expected)
assert checked==nn
(d/f'structural-equivalence{suffix}.json').write_text(json.dumps({'reachable_nodes_bitwise':True,'nodes':checked,'trees':nt,'samples':ns},indent=2)+'\n')
