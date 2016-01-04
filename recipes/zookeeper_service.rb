datacenter = node.name.split('-')[0]
location = node.name.split('-')[1]
environment = node.name.split('-')[2]
slug = node.name.split('-')[3] 
server_type = node.name.split('-')[4]

data_bag("meta_data_bag")
aws = data_bag_item("meta_data_bag", "aws")
domain = aws[node.chef_environment]["route53"]["domain"]
zone_id = aws[node.chef_environment]["route53"]["zone_id"]
AWS_ACCESS_KEY_ID = aws[node.chef_environment]['AWS_ACCESS_KEY_ID']
AWS_SECRET_ACCESS_KEY = aws[node.chef_environment]['AWS_SECRET_ACCESS_KEY']

data_bag("server_data_bag")
zookeeper_server = data_bag_item("server_data_bag", "zookeeper")
subdomain = zookeeper_server[datacenter][environment][location]['subdomain']
required_count = zookeeper_server[datacenter][environment][location]['required_count']
full_domain = "#{subdomain}.#{domain}"

if datacenter!='aws'
  do_cloud = data_bag_item("my_data_bag", "do")
  keypair = do_cloud[datacenter][node.chef_environment]["keypair"]
  username=do_cloud["username"]
end

zookeeper_hosts = "1.#{subdomain}.#{domain}"

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
zookeeper_hosts = []
for i in xrange(int(#{required_count})):
    zookeeper_hosts.append("%s.#{full_domain}" % (i+1))

ip_address_list = zookeeper_hosts
if len(ip_address_list)>=1:
  for ip_address in ip_address_list:
      keypair_path = '/root/.ssh/#{keypair}'
      key = paramiko.RSAKey.from_private_key_file(keypair_path)
      ssh = paramiko.SSHClient()
      ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
      try:
        ssh.connect(ip_address, 22, username=username, pkey=key)
        cmd = "sudo ufw allow from #{node[:ipaddress]} to any port 2181"
        stdin, stdout, stderr = ssh.exec_command(cmd)
        out = stdout.read()
        err = stderr.read()
        print "out--", out
      except:
        pass
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
f.write('#{zookeeper_hosts}')
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
  notifies :restart, resources(:service => "supervisord"), :immediately 
end
service "supervisord"

