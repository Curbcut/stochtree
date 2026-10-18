#!/usr/bin/env python3
"""Fresh-process paired timing/HWM. Local warm/uncontrolled inputs, not capacity."""
import argparse,json,pathlib,subprocess,os,platform,time,hashlib
p=argparse.ArgumentParser();p.add_argument('directory',type=pathlib.Path);p.add_argument('source',type=pathlib.Path);p.add_argument('output',type=pathlib.Path);p.add_argument('--repetitions',type=int,default=3);p.add_argument('--rlibs',default=os.environ.get('R_LIBS',''))
a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
for rep in range(1,a.repetitions+1):
 for mode,variant,artifact in [('legacy','source',a.source),('binary','all',a.directory/'forest-all.ntf'),('binary','selected',a.directory/'forest.ntf')]:
  name=f'{mode}-{variant}-r{rep}';receipt=a.output/f'{name}.json'
  env=os.environ.copy();env['R_LIBS']=a.rlibs
  env.update(OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',VECLIB_MAXIMUM_THREADS='1')
  command=['Rscript','native/benchmark.R',mode,str(a.directory),str(artifact),str(receipt)]
  with (a.output/f'{name}.log').open('w') as log:
   proc=subprocess.Popen(command,env=env,stdout=log,stderr=log)
   _,status,usage=os.wait4(proc.pid,0);proc.returncode=os.waitstatus_to_exitcode(status)
  if proc.returncode:raise RuntimeError(f'failed {name}; see log')
  data=json.loads(receipt.read_text());data.update(variant=variant,repetition=rep,
    process_peak_bytes=int(usage.ru_maxrss*(1 if platform.system()=='Darwin' else 1024)),
    user_seconds=usage.ru_utime,system_seconds=usage.ru_stime,platform=platform.platform(),
    cache_state='warm/uncontrolled local input; no independent residency proof',
    process_peak_scope='fresh R process; shared application dependencies and same preloaded reference inputs')
  receipt.write_text(json.dumps(data,indent=2)+'\n')
