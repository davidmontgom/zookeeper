import zc.zk
import time
import json
import os
import sys
import psutil
import logging #https://kazoo.readthedocs.org/en/latest/basic_usage.html
logging.basicConfig()
"""
0) load zookeeper from file written by chef
1) get ip address from file
2) register server
3) If change in servers then rerun chef
"""
# with open('/tmp/zookeeper_hosts') as f:
#     zk_host_list = json.load(f)
 
#
zk_host_list = open('/var/zookeeper_hosts.json').readlines()[0]
zk_host_list = zk_host_list.split(',')

temp = open('/var/zookeeper_node_name.json').readlines()[0]
node,ip = temp.split(' ')

node_meta = node.split('-')
node = node_meta[:-1]
node = '-'.join(node)

server_type = node_meta[0]
environment = node_meta[2]
dataceter = node_meta[1]
location = node_meta[3]



def get_process_list():
    if os.path.isfile('/var/zk_process_monitor_list.json'):
        with open("/var/zk_process_monitor_list.json") as json_file:
            process_list = json.load(json_file)
    else:
        process_list = []
    return process_list
process_list = get_process_list()
    

if os.path.isfile('/var/shard.txt'):
    shard = open('/var/shard.txt').readlines()[0].strip()
    node = "%s-%s" % (node,shard)

if environment=='local':
    ip='127.0.0.1'

for i in xrange(len(zk_host_list)):
    zk_host_list[i]=zk_host_list[i]+':2181' 
zk_host_str = ','.join(zk_host_list)

    

zk = zc.zk.ZooKeeper(zk_host_str)
path = '/%s/' % (node)
data = ''
if zk.exists(path)==None:
    zk.create_recursive(path,data,zc.zk.OPEN_ACL_UNSAFE)
#zk.register(path, (ip, 8080))
zk.register(path, (ip))
addresses = zk.children(path)
data = zk.properties(path)

def get_process(process_list):
    """
    find proccess by username or name
    port discovery is hard
    
    for zookeeper add username and java check e.g. username='zookeepeer' and name = 'java'
    """
    process_hash = {}
    for ps in process_list:
        process_hash[ps]=1
    data_hash = {}
    for proc in psutil.process_iter():
        if process_hash.has_key(proc.name()) or process_hash.has_key(proc.username()):
            if process_hash.has_key(proc.name()):
                this_name = proc.name()
            if process_hash.has_key(proc.username()):
                this_name = proc.username()
            proc_hash = proc.as_dict()
            pid = proc_hash['pid']
            p = psutil.Process(pid)
            data_hash[this_name]={'pid':pid, 'is_running':str(p.is_running())}
    return data_hash

while True:
    print path,sorted(addresses)
    time.sleep(2)
    change=False
    if change:
        os.system('sh /var/solo.sh')
    if process_list:
        data_hash = get_process(process_list)
        data.set(data_hash)
        print 'updated data:', data_hash
    sys.stdout.flush()
    sys.stderr.flush()
        
    
    
