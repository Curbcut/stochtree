#!/usr/bin/env python3
"""Run the standalone core against immutable prepared inputs; no R or release I/O."""
import argparse, json, pathlib, subprocess
p=argparse.ArgumentParser();p.add_argument('directory',type=pathlib.Path);p.add_argument('build',type=pathlib.Path)
a=p.parse_args();d=a.directory;r=json.loads((d/'receipt.json').read_text())
for mode,ids,output in [('fixed','ids.txt','standalone.bin'),('mapped','mapped-ids.txt','standalone-mapped.bin')]:
 result=subprocess.run([str(a.build/'ntf-predict'),str(d/'forest.ntf'),mode,str(r['rows']),str(r['columns']),str(d/'x.bin'),str(d/ids),str(d/output),'1'],check=True,capture_output=True,text=True)
 (d/f'{mode}-timing.json').write_text(result.stdout)
