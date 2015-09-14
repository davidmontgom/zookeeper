datacenter = node.name.split('-')[0]
server_type = node.name.split('-')[1]
location = node.name.split('-')[2]
  
data_bag("my_data_bag")
zk = data_bag_item("my_data_bag", "zk")
zk_hosts = zk[node.chef_environment][datacenter][location]["zookeeper_hosts"]

db = data_bag_item("my_data_bag", "my")
keypair=db[node.chef_environment][location]["ssh"]["keypair"]
username=db[node.chef_environment][location]["ssh"]["username"]

zk_process_monitor_list = node['zk_process_monitor']

#zookeeper_hosts = File.write("/var/zookeeper_hosts")
#File.open("/tmp/zookeeper_hosts.json","w") do |f|
#  f.write(zk_hosts.to_json)
#end

easy_install_package "zc.zk" do
  action :install
end

easy_install_package "psutil" do
  action :install
end

easy_install_package "paramiko" do
  action :install
end

=begin
if new zk node then:
  add this to them
  add them to this
=end

if datacenter!='local' and datacenter!='aws'
  script "zookeeper_add" do
    interpreter "python"
    user "root"
  code <<-PYCODE
import paramiko
username='#{username}'
zookeeper_hosts = '#{zk_hosts}'
ip_address_list = zookeeper_hosts.split(',')
for ip_address in ip_address_list:
    keypair_path = '/root/.ssh/#{keypair}'
    key = paramiko.RSAKey.from_private_key_file(keypair_path)
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(ip_address, 22, username=username, pkey=key)
    cmd = "sudo ufw allow from #{node[:ipaddress]} to any port 2181"
    stdin, stdout, stderr = ssh.exec_command(cmd)
    out = stdout.read()
    err = stderr.read()
    print "out--", out
    ssh.close()
PYCODE
  end
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
f.write('#{node.name} #{node[:ipaddress]}')
f.close()

f = open('/var/zk_process_monitor_list.json','w')
f.write('#{zk_process_monitor_list}')
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

