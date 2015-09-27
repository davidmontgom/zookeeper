import zc.zk
from kazoo.client import KazooClient
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

#zk_host_list = '107.170.219.233'
zk_host_list = open('/var/zookeeper_hosts.json').readlines()[0]
zk_host_list = zk_host_list.split(',')
temp = open('/var/zookeeper_node_name.json').readlines()[0]
node,ip = temp.split(' ')

# node = 'do-fu-sf-development'
# ip = '111.111.111.111'
# print node,ip

node_meta = node.split('-')
node = node_meta[:-1]
node = '-'.join(node)

server_type = node_meta[0]
environment = node_meta[2]
dataceter = node_meta[1]
location = node_meta[3]

if os.path.isfile('/var/shard.txt'):
    shard = open('/var/shard.txt').readlines()[0].strip()
    node = "%s-%s" % (node,shard)

if environment=='local':
    ip='127.0.0.1'

for i in xrange(len(zk_host_list)):
    zk_host_list[i]=zk_host_list[i]+':2181' 
zk_host_str = ','.join(zk_host_list)
path = '/%s/' % (node)
  

def get_zk_conn():
    zk = KazooClient(hosts=zk_host_str, read_only=True)
    zk.start()
    return zk
zk = get_zk_conn()
 
if zk.exists(path)==None:
    zk.create(path,'', ephemeral=False)

if zk.exists(path + ip)==None:
    zk.create(path + ip,'', ephemeral=True)
 
while True:
    children = zk.get_children(path)
    print path,list(children)
    sys.stdout.flush()
    sys.stderr.flush()
    time.sleep(.5)
 
        
    
    
