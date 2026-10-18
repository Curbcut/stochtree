#!/usr/bin/env python3
import argparse,json,pathlib,subprocess
p=argparse.ArgumentParser();p.add_argument('directory',type=pathlib.Path);p.add_argument('build',type=pathlib.Path);a=p.parse_args();d=a.directory
plan=json.loads((d/'plan.json').read_text());all_plan=dict(plan)
all_plan['positions']=list(range(len(plan['source_original_ids'])));all_plan['original_ids']=plan['source_original_ids']
(d/'plan-all.json').write_text(json.dumps(all_plan,indent=2)+'\n')
for suffix,config in [('',d/'plan.json'),('-all',d/'plan-all.json')]:
 result=subprocess.run([str(a.build/'ntf-convert'),str(d/'model.json'),str(config),str(d/f'forest{suffix}.ntf')],check=True,capture_output=True,text=True)
 (d/f'conversion{suffix}.json').write_text(result.stdout)
