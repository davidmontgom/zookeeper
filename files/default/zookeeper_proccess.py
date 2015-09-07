import zc.zk
import time
import json
import os
import sys
import psutil
from pprint import pprint
import time
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
# zk_host_list = open('/var/zookeeper_hosts.json').readlines()[0]
# zk_host_list = zk_host_list.split(',')
zk_host_list = ['192.241.233.107']

#temp = open('/var/zookeeper_node_name.json').readlines()[0]
temp ='a-b-c-d-e 111.111.111.111'
node,ip = temp.split(' ')

if os.path.isfile('/var/zk_process_monitor_list.json'):
    with open("/var/zk_process_monitor_list.json") as json_file:
        process_list = json.load(json_file)
else:
    process_list = []
    
    
    
process_list = ['zookeeper']
   


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

#node = 'do-frontend-sf-development'
zk = zc.zk.ZooKeeper(zk_host_str)
path = '/%s-process/' % (node)
data = ''
data = zk.properties(path)
addresses = zk.children(path)
print dir(addresses)
print data, data.items()


if zk.exists(path)==None:
    zk.create_recursive(path,data,zc.zk.OPEN_ACL_UNSAFE)
#zk.register(path, (ip, 8080))
zk.register(path, (ip))
addresses = zk.children(path)
data = zk.properties(path + ip)
#data = zk.properties(path)
#print data.items()
print dir(data)

print zk.is_ephemeral(path)

exit()
#print data.real_path
data.update({'etaa':'adadf'})
exit()
#   
# p = psutil.Process(3077)
# for connection in p.connections():
#     if connection.status=='LISTEN':
#         print connection
# 
# exit()



# [pconn(fd=24, family=10, type=1, laddr=('::ffff:127.0.0.1', 2181), raddr=('::ffff:127.0.0.1', 61662), status='ESTABLISHED'),
#  pconn(fd=14, family=10, type=1, laddr=('::', 33452), raddr=(), status='LISTEN'),
#  pconn(fd=23, family=10, type=1, laddr=('::ffff:127.0.0.1', 2181), raddr=('::ffff:127.0.0.1', 61660), status='ESTABLISHED'),
#  pconn(fd=21, family=10, type=1, laddr=('::ffff:127.0.0.1', 2181), raddr=('::ffff:127.0.0.1', 61657), status='ESTABLISHED'),
#  pconn(fd=20, family=10, type=1, laddr=('::', 2181), raddr=(), status='LISTEN')]
# 
# 
# 
# exit()
# pid_hash = {}
# for pp in ports:
#     print pp
#     #pid_hash[pp.pid]=pp.laddr
          
      
#pprint(pid_hash)
#exit()
# 
# p = psutil.Process(2760)
# #connection_status = defaultdict(int)
# for connection in p.get_connections():
#     print connection
#     connection_status[connection.status] += 1
#     connection_status['total'] += 1
     


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
            #data_hash[this_name] = {'pid':pid, 'is_running':str(p.is_running())}
            data_hash[ip]= {this_name:{'pid':pid, 'is_running':str(p.is_running())}}
    return data_hash

# data = get_process(process_list)
# print data
# exit()

while True:
    print path,sorted(addresses)
    print 'remote data:',data.items()
    data_hash = get_process(process_list)
    data.update(data_hash)
    #data.set(data_hash)
    print 'updated data:', data_hash
    print '*'*80
    time.sleep(2)
    change=False
    sys.stdout.flush()
    sys.stderr.flush()














