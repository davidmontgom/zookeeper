import zc.zk
import time
import json
import os
import sys

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

# server_type = node_meta[0]
# environment = node_meta[2]
# dataceter = node_meta[1]
# location = node_meta[3]

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
while True:
    print path,sorted(addresses)
    time.sleep(2)
    change=False
    if change:
        os.system('sh /var/solo.sh')
    sys.stdout.flush()
    sys.stderr.flush()
        
    
    
