server_type = node.name.split('-')[0]
slug = node.name.split('-')[1] 
datacenter = node.name.split('-')[2]
environment = node.name.split('-')[3]
location = node.name.split('-')[4]
cluster_slug = File.read("/var/cluster_slug.txt")
cluster_slug = cluster_slug.gsub(/\n/, "") 
cluster_index = File.read("/var/cluster_index.txt")
cluster_index = cluster_index.gsub(/\n/, "") 

data_bag("meta_data_bag")
aws = data_bag_item("meta_data_bag", "aws")
domain = aws[node.chef_environment]["route53"]["domain"]
zone_id = aws[node.chef_environment]["route53"]["zone_id"]
AWS_ACCESS_KEY_ID = aws[node.chef_environment]['AWS_ACCESS_KEY_ID']
AWS_SECRET_ACCESS_KEY = aws[node.chef_environment]['AWS_SECRET_ACCESS_KEY']

data_bag("server_data_bag")
zookeeper_server = data_bag_item("server_data_bag", "zookeeper")

if cluster_slug=="nocluster"
  subdomain = "zookeeper-#{slug}-#{datacenter}-#{environment}-#{location}"
else
  subdomain = "zookeeper-#{slug}-#{datacenter}-#{environment}-#{location}-#{cluster_slug}"
end
required_count = zookeeper_server[datacenter][environment][location][cluster_slug]['required_count']
full_domain = "#{subdomain}.#{domain}"
  
  
bash "install_zookeeper_boto" do
  code <<-EOH
  	pip install boto
  EOH
end

#https://github.com/apache/zookeeper/tree/trunk/src/contrib/rest/src
#wget http://www.us.apache.org/dist/zookeeper/zookeeper-3.4.12/zookeeper-3.4.12.tar.gz
#wget https://archive.apache.org/dist/zookeeper/zookeeper-3.4.13/zookeeper-3.4.13.tar.gz
#     https://archive.apache.org/dist/zookeeper/zookeeper-3.4.13/zookeeper-3.4.13.tar.gz
version = '3.4.13'
bash "install_zookeeper" do
  user "root"
  cwd "/var"
  code <<-EOH
  #wget http://www.us.apache.org/dist/zookeeper/zookeeper-#{version}/zookeeper-#{version}.tar.gz
  #wget https://archive.apache.org/dist/zookeeper/zookeeper-#{version}/zookeeper-#{version}.tar.gz
  wget https://archive.apache.org/dist/zookeeper/zookeeper-3.4.13/zookeeper-3.4.13.tar.gz
  tar -xvf zookeeper-#{version}.tar.gz
  #mv zookeeper-#{version}.tar.gz zookeeper
  touch /var/chef/cache/zk.lock
  EOH
  action :run
  #not_if {File.exists?("/var/zookeeper-#{version}")}
  not_if {File.exists?("/var/chef/cache/zk.lock")}
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

this_ip = '#{node[:ipaddress]}'
if not os.path.isfile("/var/zookeeper_hosts_overide.lock"): 
  conn = Route53Connection('#{AWS_ACCESS_KEY_ID}', '#{AWS_SECRET_ACCESS_KEY}')
  records = conn.get_all_rrsets('#{zone_id}')
  host_list = {}
  prefix={}
  prefix_ip_hash = {}
  root = None
  for record in records:
    if record.name.find('#{subdomain}')>=0:
      if record.resource_records[0]!='#{node[:ipaddress]}':
        host_list[record.name]=record.resource_records[0]
        p = record.name.split('-')[0]
        prefix[p]=1
        root = record.name[:-1]
        prefix_ip_hash[p]=record.resource_records[0]
  
  
  
  base_domain = '#{full_domain}'
  if prefix.has_key('1')==False:
    this_prefix = '1'
  elif prefix.has_key('2')==False:
    this_prefix = '2'
  elif prefix.has_key('3')==False:
    this_prefix = '3'
  elif prefix.has_key('4')==False:
    this_prefix = '4'
  else:
    this_prefix = '5' 
  prefix_ip_hash[this_prefix]='#{node[:ipaddress]}'
  
  this_host = this_prefix + '-' + base_domain
  this_host = 'server.%s' % this_prefix
  host_list[this_host]=this_prefix + '-' + base_domain
  
else:
  this_prefix = "#{cluster_index}"
  with open('/var/cluster_index_zookeeper_hosts.json') as data_file:    
    prefix_ip_hash = json.load(data_file)
    
  f = open('/var/zookeeper_hosts','w')
  for k,v in prefix_ip_hash.iteritems():
      f.write('server.%s=%s:2888:3888' % (k,v))
      f.write("""\n""")
  f.close()
  
  
if not os.path.isfile('/var/lib/zookeeper/myid'): 
  os.system("mkdir -p /var/lib/zookeeper/")
  os.system("chmod 751 /var/lib/zookeeper/")
  os.system("touch /var/lib/zookeeper/myid")
  cmd = """echo '%s' | tee -a /var/lib/zookeeper/myid""" % this_prefix
  os.system(cmd)
  

if not os.path.isfile("/var/zookeeper_hosts_overide.lock"): 
  with open('/var/zookeeper_hosts.json', 'w') as fp:
    json.dump(host_list, fp)
  fnl=["/var/zookeeper_hosts.json"]
  fh = [(fname, hashlib.md5(open("/var/zookeeper_hosts.json", 'rb').read()).hexdigest()) for fname in fnl][0][1]
  hash_file = '/var/fh_%s' % fh
  if not os.path.isfile(hash_file):
    try:
      os.system('rm /var/fh_*')
    except:
      pass
    os.system('touch %s' % hash_file)
    f = open('/var/zookeeper_hosts','w')
    for k,v in prefix_ip_hash.iteritems():
        f.write('server.%s=%s:2888:3888' % (k,v))
        f.write("""\n""")
    f.close()

PYCODE

end



=begin
nodename = node.name.to_s.gsub('_', '-')
execute "change_hostname" do
  command " echo '127.0.0.2    #{nodename}' | tee -a /etc/hosts"
  action :run
  not_if {File.exists?("#{Chef::Config[:file_cache_path]}/hostname")}
end
execute "change_hostname" do
  command " echo '#{nodename}' > /etc/hostname;hostname -F /etc/hostname;/etc/init.d/hostname restart"
  action :run
  not_if {File.exists?("#{Chef::Config[:file_cache_path]}/hostname")}
end
file "#{Chef::Config[:file_cache_path]}/hostname" do
  owner "root"
  group "root"
  mode "0755"
  action :create
end
=end

=begin
  
=end

if File.exists?("/var/zookeeper_hosts")
    zookeeper_hosts = File.read("/var/zookeeper_hosts")
end


service "supervisord"
template "/var/zookeeper-#{version}/conf/zoo.cfg" do
  path "/var/zookeeper-#{version}/conf/zoo.cfg"
  source "zoo.cfg.raw.erb"
  owner "root"
  group "root"
  mode "0644"
  #variables :zookeeper => zookeeper_hosts
  variables lazy {{:zookeeper => File.read("/var/zookeeper_hosts")}}
  notifies :restart, resources(:service => "supervisord")
end


template "/etc/supervisor/conf.d/zookeeper.conf" do
  path "/etc/supervisor/conf.d/zookeeper.conf"
  source "supervisord.zookeeper.conf.erb"
  owner "root"
  group "root"
  mode "0755"
  notifies :restart, resources(:service => "supervisord")
  variables :version => version
end



#logrotate -d -f /etc/logrotate.d/zookeeper-rotate 
#/var/lib/zookeeper/version-2/
=begin
logrotate_app "zookeeper-rotate" do
  cookbook "logrotate"
  path ["/var/lib/zookeeper/version-2/log.*","/var/lib/zookeeper/version-2/snapshot.*"]
  frequency "daily"
  rotate 1
  #size "10M"
  create "644 root root"
end
=end


cron 'noop_log' do
  hour '5'
  minute '0'
  command '/bin/rm /var/lib/zookeeper/version-2/log.* 2>/dev/null'
end

cron 'noop_status' do
  hour '5'
  minute '0'
  command '/bin/rm /var/lib/zookeeper/version-2/status.* 2>/dev/null'
end


#  echo stat | nc 127.0.0.1 2181

