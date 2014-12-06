datacenter = node.name.split('-')[0]
server_type = node.name.split('-')[1]
location = node.name.split('-')[2]

data_bag("my_data_bag")
db = data_bag_item("my_data_bag", "my")




#zookeeper = db[node.chef_environment][location]['zookeeper']

package "zookeeper-server" do
  action :install
end

bash "install_zookeeper" do
  user "root"
  cwd "#{Chef::Config[:file_cache_path]}"
  code <<-EOH
    sudo service zookeeper-server init
    touch zookeeper-server-init.lock
  EOH
  action :run
  not_if {File.exists?("#{Chef::Config[:file_cache_path]}/zookeeper-server-init.lock")}
end

=begin
myid = node[:ipaddress].to_s.gsub('.', '')
file "/var/lib/zookeeper/myid" do
  content "#{myid}"
  action :create
end
=end



service "zookeeper-server" do
  supports :restart => true, :start => true, :stop => true, :status => true
  action [:start,:enable]
end


if datacenter != "local"
  
AWS_ACCESS_KEY_ID = db[node.chef_environment]['aws']['AWS_ACCESS_KEY_ID']
AWS_SECRET_ACCESS_KEY = db[node.chef_environment]['aws']['AWS_SECRET_ACCESS_KEY']
zone_id = db[node.chef_environment]['aws']['route53']['zone_id']
domain = db[node.chef_environment]['aws']['route53']['domain']

easy_install_package "boto" do
  action :install
end

script "zookeeper_myid" do
  interpreter "python"
  user "root"
  cwd "/root"
code <<-PYCODE
import json
import os
from boto.route53.connection import Route53Connection
from boto.route53.record import ResourceRecordSets
from boto.route53.record import Record
import hashlib

conn = Route53Connection('#{AWS_ACCESS_KEY_ID}', '#{AWS_SECRET_ACCESS_KEY}')
records = conn.get_all_rrsets('#{zone_id}')
host_list = {}
prefix={}
root = None
for record in records:
  if record.name.find('zk')>=0 and record.name.find('#{location}')>=0 and record.name.find('#{node.chef_environment}')>=0:
    if record.resource_records[0]!='#{node[:ipaddress]}':
      host_list[record.name]=record.resource_records[0]
      p = record.name.split('.')[0]
      prefix[p]=1
      root = record.name[:-1]


this_ip = '#{node[:ipaddress]}'
base_domain = 'zk.#{datacenter}.#{node.chef_environment}.#{location}.#{domain}'
if prefix.has_key('1')==False:
  this_prefix = '1'
elif prefix.has_key('2')==False:
  this_prefix = '2'
elif prefix.has_key('3')==False:
  this_prefix = '3'
else:
  this_prefix = '4' 
  
if not os.path.isfile('/var/lib/zookeeper/myid'): 
  os.system("touch /var/lib/zookeeper/myid")
  cmd = """echo '%s' | tee -a /var/lib/zookeeper/myid""" % this_prefix
  os.system(cmd)
  

  
this_host = this_prefix + '.' + base_domain
host_list[this_host]=this_ip


with open('#{Chef::Config[:file_cache_path]}/zookeeper_hosts.json', 'w') as fp:
  json.dump(host_list, fp)
fnl=["#{Chef::Config[:file_cache_path]}/zookeeper_hosts.json"]
fh = [(fname, hashlib.md5(open("#{Chef::Config[:file_cache_path]}/zookeeper_hosts.json", 'rb').read()).hexdigest()) for fname in fnl][0][1]
hash_file = '#{Chef::Config[:file_cache_path]}/fh_%s' % fh
if not os.path.isfile(hash_file):
  try:
    os.system('rm #{Chef::Config[:file_cache_path]}/fh_*')
  except:
    pass
  os.system('touch %s' % hash_file)
  f = open('/var/chef/cache/zookeeper_hosts','w')
  for k,v in host_list.iteritems():
      f.write(k + "=" + v + ":2888:3888")
      f.write("""\n""")
  f.close()


th = {}
th[this_host]=this_ip
with open('#{Chef::Config[:file_cache_path]}/this_host.json', 'w') as fp:
  json.dump(th, fp)

PYCODE
end


script "change_hostname" do
  interpreter "python"
  user "root"
  cwd "/root"
code <<-PYCODE
import json
import os
with open("/var/chef/cache/this_host.json") as json_file:
    json_data = json.load(json_file)
hostname = json_data.keys()[0]
host = hostname.split('.')[:-2]
host = '.'.join(host)
cmd = """sed -i '/^127\.0\.1\.1/s/^/#/' /etc/hosts"""
os.system(cmd)
nm = """\n127.0.1.1 %s %s\n""" % (hostname,host)
cmd = """echo '%s' | tee -a /etc/hosts""" % (nm)
os.system(cmd)
cmd = """cp /etc/hosts /etc/hosts.original"""
os.system(cmd)
cmd = "> /etc/hostname"
os.system(cmd)
cmd = """echo '%s' | tee -a /etc/hostname""" % host
os.system(cmd)
cmd = "/etc/init.d/hostname restart"
os.system(cmd)
cmd = "touch #{Chef::Config[:file_cache_path]}/hostname.lock"
os.system(cmd)
PYCODE
not_if {File.exists?("#{Chef::Config[:file_cache_path]}/hostname.lock")}
end


if File.exists?("#{Chef::Config[:file_cache_path]}/zookeeper_hosts")
    zookeeper_hosts = File.read("#{Chef::Config[:file_cache_path]}/zookeeper_hosts")
end

=begin
zookeeper_hosts = Hash.new
zookeeper_hosts["1.zk.aws.development.west.augnodev.com"]="172.31.2.155"
=end


template "/etc/zookeeper/conf/zoo.cfg" do
  path "/etc/zookeeper/conf/zoo.cfg"
  source "cloudera.zoo.cfg.erb"
  owner "root"
  group "root"
  mode "0644"
  variables :zookeeper => zookeeper_hosts
  notifies :restart, resources(:service => "zookeeper-server")
end



end














