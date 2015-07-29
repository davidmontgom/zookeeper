datacenter = node.name.split('-')[0]
server_type = node.name.split('-')[1]
location = node.name.split('-')[2]
  
data_bag("my_data_bag")
zk = data_bag_item("my_data_bag", "zk")
zk_hosts = zk[node.chef_environment][datacenter][location]["zookeeper_hosts"]


#zookeeper_hosts = File.write("/var/zookeeper_hosts")
#File.open("/tmp/zookeeper_hosts.json","w") do |f|
#  f.write(zk_hosts.to_json)
#end

easy_install_package "zc.zk" do
  action :install
end

script "zookeeper_files" do
  interpreter "python"
  user "root"
code <<-PYCODE
import json
f = open('/var/zookeeper_hosts.json','w')
f.write('#{zk_hosts}')
f.close()

f = open('/var/zookeeper_node_name.json','w')
f.write('#{server_type}-#{datacenter}-#{node.chef_environment}-#{location} #{node[:ipaddress]}')
f.close()

PYCODE
end

cookbook_file "/var/zookeeper_service.py" do
  source "zookeeper_service.py"
  mode 00744
end

template "/etc/supervisor/conf.d/supervisord.zookeeper.health.include.conf" do
  path "/etc/supervisor/conf.d/supervisord.zookeeper.health.include.conf"
  source "supervisord.zookeeper.health.include.conf.erb"
  owner "root"
  group "root"
  mode "0755"
  notifies :restart, resources(:service => "supervisord")
end
service "supervisord"

