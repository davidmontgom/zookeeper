
import psutil
from pprint import pprint
import time
process_hash = {}
process_list['nginx']



"""
1) write to zookeeper
2) write running proccess
"""







for proc in psutil.process_iter():
    
#     pprint(dir(proc))
#     exit()
    if proc.name()=='nginx':
        proc_hash = proc.as_dict()
        #pprint(proc_hash)
        pid = proc_hash['pid']
        p = psutil.Process(pid)
#         print p.connections()
        print p.name()
        print p.is_running()
#         print dir(p)




