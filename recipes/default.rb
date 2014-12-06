data_bag("rtb_data_bag")
db = data_bag_item("rtb_data_bag", "rtb")
AWS_ACCESS_KEY_ID = db[node.chef_environment]['aws']['AWS_ACCESS_KEY_ID']
AWS_SECRET_ACCESS_KEY = db[node.chef_environment]['aws']['AWS_SECRET_ACCESS_KEY']
zookeeper = db[node.chef_environment]['zookeeper']
location = node.chef_environment.split('-')[2]
platform = node.chef_environment





if platform == 'production'
  domain = 'rtbhui.com'
end
if platform == 'development'
  domain = 'devrtbhui.com'
end

if location=='hongkong'
  loc = 'hk'
end
if location=='singapore'
  loc = 'sg'
end



package "zookeeper" do
  action :install
end
package "zookeeperd" do
  action :install
end
package "zookeeper-bin" do
  action :install
end

service "zookeeper" do
  supports :restart => true, :start => true, :stop => true, :status => true, :reload => true
  action [ :enable]
end



easy_install_package "zc-zookeeper-static" do
  action :install
end
easy_install_package "pykeeper" do
  action :install
end

=begin
easy_install_package "boto" do
action :install
end
template "/root/.boto" do
path "/root/.boto"
source "boto.erb"
owner "root"
group "root"
mode "0644"
variables({
:AWS_ACCESS_KEY_ID => "#{AWS_ACCESS_KEY_ID}", :AWS_SECRET_ACCESS_KEY => "#{AWS_SECRET_ACCESS_KEY}"
})
end

git "#{Chef::Config[:file_cache_path]}/Area53" do
repository "git://github.com/mariusv/Area53.git"
action :checkout
user "root"
end

bash "compile_Area53" do
cwd "#{Chef::Config[:file_cache_path]}/Area53"
code <<-EOH
python setup.py install
EOH
not_if {File.exists?("#{Chef::Config[:file_cache_path]}/area53.lock")}
end
file "#{Chef::Config[:file_cache_path]}/area53.lock" do
owner "root"
group "root"
mode "0755"
action :create
end
=end



script "zookeeper_myid" do
  interpreter "python"
  user "root"
  cwd "/tmp"
code <<-PYCODE
import json
from area53 import route53
zone = route53.get_zone('#{domain}')
host_list = {}
prefix={}
root = None
for record in zone.get_records():
if record.name.find('dzk')>=0 and record.name.find('#{loc}')>=0:
host_list[record.name]=record.resource_records[0]
p = record.name.split('.')[0]
prefix[p]=1
root = record.name

this_ip = '#{node[:ipaddress]}'
base_domain = 'dzk.'+ '#{loc}' + '.' + '#{domain}'
if prefix.has_key('1')==False:
this_prefix = '1'
elif prefix.has_key('2')==False:
this_prefix = '2'
elif prefix.has_key('3')==False:
this_prefix = '3'
else:
this_prefix = '4'
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
  #not_if {File.exists?("/etc/zookeeper/conf/myid")}
end

#contents = File.read('/tmp/znodes.json')
#zookeeper_hash = JSON.parse(contents)




nodename = node.name.to_s.gsub('_', '-')
execute "change_hostname" do
  command " echo '127.0.0.2 #{nodename}' | tee -a /etc/hosts"
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


template "/etc/zookeeper/conf/zoo.cfg" do
  path "/etc/zookeeper/conf/zoo.cfg"
  source "zoo.cfg.erb"
  owner "root"
  group "root"
  mode "0644"
  variables :zookeeper => zookeeper
  notifies :reload, resources(:service => "zookeeper"), :immediately
end


