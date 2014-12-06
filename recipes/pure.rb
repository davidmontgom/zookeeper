location = node.name.split('-')[2]

data_bag("my_data_bag")
db = data_bag_item("my_data_bag", "my")
AWS_ACCESS_KEY_ID = db[node.chef_environment]['aws']['AWS_ACCESS_KEY_ID']
AWS_SECRET_ACCESS_KEY = db[node.chef_environment]['aws']['AWS_SECRET_ACCESS_KEY']
zone_id = db[node.chef_environment]['aws']['r53_zone_id']
zookeeper = db[node.chef_environment][location]['druid']['zookeeper']
domain =  db[node.chef_environment]['domain']


easy_install_package "boto" do
  action :install
end
=begin
 
 if templates change use supervisorctl restart rather then service supervisord restart
 
=end

version = node['zookeeper']['version']
cookbook_file "#{Chef::Config[:file_cache_path]}/zookeeper-#{version}.tar.gz" do
  source "zookeeper-#{version}.tar.gz" # this is the value that would be inferred from the path parameter
  mode 00644
  not_if {File.exists?("#{Chef::Config[:file_cache_path]}/zookeeper_lock")}
end

bash "install_zookeeper" do
  user "root"
  cwd "#{Chef::Config[:file_cache_path]}"
  code <<-EOH
  tar -xf zookeeper-#{version}.tar.gz
  #mv zookeeper-#{version}.tar.gz zookeeper
  EOH
  action :run
  not_if {File.exists?("#{Chef::Config[:file_cache_path]}/zookeeper_lock")}
end
execute "kill2181" do
   command "sudo kill `sudo lsof -t -i:2181`"
   action :run
   ignore_failure true
   not_if {File.exists?("#{Chef::Config[:file_cache_path]}/zookeeper_lock")}
end
file "#{Chef::Config[:file_cache_path]}/zookeeper_lock" do
  owner "root"
  group "root"
  mode "0755"
  action :create
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


conn = Route53Connection('#{AWS_ACCESS_KEY_ID}', '#{AWS_SECRET_ACCESS_KEY}')
records = conn.get_all_rrsets('#{zone_id}')
host_list = {}
prefix={}
root = None
for record in records:
  if record.name.find('dzk')>=0 and record.name.find('#{location}')>=0:
    host_list[record.name]=record.resource_records[0]
    p = record.name.split('.')[0]
    prefix[p]=1
    root = record.name[:-1]


this_ip = '#{node[:ipaddress]}'
base_domain = 'dzk.'+ '#{location}' + '.' + '#{domain}'
if prefix.has_key('1')==False:
  this_prefix = '1'
elif prefix.has_key('2')==False:
  this_prefix = '2'
elif prefix.has_key('3')==False:
  this_prefix = '3'
else:
  this_prefix = '4' 
  
#f = open('/etc/zookeeper/conf/myid','w')
#f.write(str(this_prefix))
#f.close()

f = open('#{Chef::Config[:file_cache_path]}/zookeeper-#{version}/conf/myid','w')
f.write(str(this_prefix))
f.close()

  
this_host = this_prefix + '.' + base_domain
host_list[this_host]=this_ip
with open('/tmp/znodes.json', 'wb') as fp:
  json.dump(host_list, fp)

f = open('/tmp/znodes.txt','w')
for host,ip in host_list.iteritems():
  temp = "%s\t%s" % (host,ip)
  f.write(temp)
#temp = "%s\t%s" % (this_host,this_ip)
f.write(temp)
  
f.close()

PYCODE
  #not_if {File.exists?("#{Chef::Config[:file_cache_path]}/myid")}
end
file "#{Chef::Config[:file_cache_path]}/myid" do
  owner "root"
  group "root"
  mode "0755"
  action :create
end


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

service "supervisord"

template "#{Chef::Config[:file_cache_path]}/zookeeper-#{version}/conf/zoo.cfg" do
  path "#{Chef::Config[:file_cache_path]}/zookeeper-#{version}/conf/zoo.cfg"
  source "zoo.cfg.erb"
  owner "root"
  group "root"
  mode "0644"
  variables :zookeeper => zookeeper
  notifies :restart, resources(:service => "supervisord")
end

template "/etc/supervisor/conf.d/zookeeper.conf" do
  path "/etc/supervisor/conf.d/zookeeper.conf"
  source "supervisord.zookeeper.conf.erb"
  owner "root"
  group "root"
  mode "0755"
  notifies :restart, resources(:service => "supervisord")
end




