import zc.zk
from kazoo.client import KazooClient
import time
import json
import os
import sys
import psutil
import json
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

#aws-east-development-trade-zookeeper


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
    
cluster_index = None
if os.path.exists('/var/cluster_index.txt'):
    cluster_index = open('/var/cluster_index.txt').readlines()[0].strip()
    data = {'cluster_index':cluster_index}
    data = json.dumps(data)
    res = zk.set(path + ip, data)
    print 'node data:',data
    print 'path:',path + ip
    print 'res:',res
    
# data = zk.properties(path + ip)
# cluster_info = {'cluster_index': cluster_index}
# data.update(cluster_info)


 
while True:
    try:
        children = zk.get_children(path)
    except:
        zk = get_zk_conn()
    print path,list(children)
    if ip not in list(children):
        zk.create(path + ip,'', ephemeral=True)
    sys.stdout.flush()
    sys.stderr.flush()
    time.sleep(1)
 
        
    
    
