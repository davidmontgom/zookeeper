import zc.zk
from kazoo.client import KazooClient
import dns.resolver
import hashlib
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

while os.path.exists('/var/chef/cache/zookeeper.ok')==False:
    # This file is written only after the first successful chef run
    print 'waiting for OK...'
    time.sleep(1)


zk_chksum_init = hashlib.md5(open('/var/zookeeper_hosts.json', 'rb').read()).hexdigest()

def get_zk_host_list():
    zk_host_list_dns = open('/var/zookeeper_hosts.json').readlines()[0]
    zk_host_list_dns = zk_host_list_dns.split(',')
    zk_host_list = []
    for aname in zk_host_list_dns:
        try:
            data =  dns.resolver.query(aname, 'A')
            zk_host_list.append(data[0].to_text()+':2181')
        except:
            print 'ERROR, dns.resolver.NXDOMAIN',aname
    return zk_host_list

def get_zk_host_str(zk_host_list):
    zk_host_str = ','.join(zk_host_list)
    return zk_host_str

# zk_host_list = get_zk_host_list()
# zk_host_str = get_zk_host_str(zk_host_list)

temp = open('/var/zookeeper_node_name.json').readlines()[0]
node,ip = temp.split(' ')
node_meta = node.split('-')
node = node_meta[:-1]
node = '-'.join(node)
path = '/%s/' % (node)

def get_zk_conn():
    zk_host_list = get_zk_host_list()
    if zk_host_list:
        zk_host_str = get_zk_host_str(zk_host_list)
        zk = KazooClient(hosts=zk_host_str, read_only=True)
        zk.start()
    else:
        zk = None
        print 'waiting for zk conn...'
        time.sleep(1)
    return zk

zk = None
while zk==None:
    zk = get_zk_conn()
 
if zk.exists(path)==None:
    zk.create(path,'', ephemeral=False)

if zk.exists(path + ip)==None:
    zk.create(path + ip,'', ephemeral=True)
    
def add_data(zk):
    cluster_index = None
    data = {}
    if os.path.exists('/var/cluster_index.txt'):
        cluster_index = open('/var/cluster_index.txt').readlines()[0].strip()
        data['cluster_index']=cluster_index
    if os.path.exists('/var/vpn_ip_address.txt'):
        vpn_ip_address = open('/var/vpn_ip_address.txt').readlines()[0].strip()
        data['vpn_ip_address']=vpn_ip_address
    
    if data:
        data = json.dumps(data)
        res = zk.set(path + ip, data)
        print 'node data:',data
        print 'path:',path + ip
        print 'res:',res

add_data(zk)



 
while True:
    zk_chksum = hashlib.md5(open('/var/zookeeper_hosts.json', 'rb').read()).hexdigest()
    if zk_chksum!=zk_chksum:
        zk = get_zk_conn()
        
    try:
        children = zk.get_children(path)
    except:
        zk = get_zk_conn()
    print path,list(children)
    add_data(zk)
    if ip not in list(children):
        zk.create(path + ip,'', ephemeral=True)
    sys.stdout.flush()
    sys.stderr.flush()
    time.sleep(1)
 
        
        
    
    
