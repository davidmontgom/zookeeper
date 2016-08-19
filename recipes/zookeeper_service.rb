server_type = node.name.split('-')[0]
slug = node.name.split('-')[1] 
datacenter = node.name.split('-')[2]
environment = node.name.split('-')[3]
location = node.name.split('-')[4]
cluster_slug = File.read("/var/cluster_slug.txt")
cluster_slug = cluster_slug.gsub(/\n/, "") 

data_bag("meta_data_bag")
aws = data_bag_item("meta_data_bag", "aws")
domain = aws[node.chef_environment]["route53"]["domain"]
zone_id = aws[node.chef_environment]["route53"]["zone_id"]
AWS_ACCESS_KEY_ID = aws[node.chef_environment]['AWS_ACCESS_KEY_ID']
AWS_SECRET_ACCESS_KEY = aws[node.chef_environment]['AWS_SECRET_ACCESS_KEY']



data_bag("server_data_bag")
zookeeper_server = data_bag_item("server_data_bag", "zookeeper")

if zookeeper_server[datacenter][environment][location].has_key?(cluster_slug)
  cluster_slug_zookeeper = cluster_slug
else
  cluster_slug_zookeeper = "nocluster"
end

if cluster_slug_zookeeper=="nocluster"
  subdomain = "zookeeper-#{slug}-#{datacenter}-#{environment}-#{location}"
else
  subdomain = "zookeeper-#{slug}-#{datacenter}-#{environment}-#{location}-#{cluster_slug_zookeeper}"
end

required_count = zookeeper_server[datacenter][environment][location][cluster_slug_zookeeper]['required_count']
full_domain = "#{subdomain}.#{domain}"


if datacenter!='aws'
  dc_cloud = data_bag_item("meta_data_bag", "#{datacenter}")
  keypair = dc_cloud[node.chef_environment]["keypair"]
  username = dc_cloud["username"]
end
if datacenter=='aws'
  dc_cloud = data_bag_item("meta_data_bag", "#{datacenter}")
  keypair = dc_cloud[node.chef_environment][location]["keypair"]
  username = dc_cloud["username"]
end

#zookeeper_hosts = "1.#{subdomain}.#{domain}"

zk_process_monitor_list = node['zk_process_monitor']
#zookeeper_hosts = File.write("/var/zookeeper_hosts")
#File.open("/tmp/zookeeper_hosts.json","w") do |f|
#  f.write(zk_hosts.to_json)
#end


package "libssl-dev" do
  action [:install,:upgrade]
end

package "libffi-dev" do
  action [:install,:upgrade]
end



python_package 'zc.zk'
python_package 'psutil'
python_package 'paramiko'
python_package 'dnspython'

=begin
python_package 'pip2pi' do
  version '0.6.8'
end

easy_install_package "zc.zk" do
  action :install
end

easy_install_package "psutil" do
  action :install
end

easy_install_package "paramiko" do
  options "-U"
  action :install
end

easy_install_package "dnspython" do
  action :install
end
=end

package "libffi-dev" do
  action :install
end

package "libssl-dev" do
  action :install
end



cookbook_file "/var/zoo.py" do
  source "zoo.py"
  mode "700"
end

cookbook_file "/var/zookeeper_cluster.py" do
  source "zookeeper_cluster.py"
  mode "700"
end

if datacenter!='local' and datacenter!='aws'
bash "zookeeper_cluster" do
    user "root"
    code <<-EOH
      /usr/bin/python /var/zookeeper_cluster.py --server_type #{server_type} \
                        --username #{username} \
                        --ip_address #{node[:ipaddress]} \
                        --zk_count #{required_count} \
                        --zk_hostname #{full_domain} \
                        --datacenter #{datacenter} \
                        --environment #{environment} \
                        --location #{location} \
                        --slug #{slug} \
                        --cluster_slug #{cluster_slug} \
                        --keypair #{keypair}
    EOH
    action :run
end
end
    

      


script "zookeeper_files" do
  interpreter "python"
  user "root"
code <<-PYCODE
import json
import os

zookeeper_hosts = []
for i in xrange(int(#{required_count})):
    zookeeper_hosts.append("%s-#{full_domain}" % (i+1))
zookeeper_hosts = ','.join(zookeeper_hosts)


if not os.path.exists('/var/zookeeper_hosts_overide.lock'):
  f = open('/var/zookeeper_hosts.json','w')
  f.write(zookeeper_hosts)
  f.close()
  
  
  
  f = open('/var/zk_process_monitor_list.json','w')
  f.write('#{zk_process_monitor_list}')
  f.close()

f = open('/var/zookeeper_node_name.json','w')
f.write('#{node.name} #{node[:ipaddress]}')
f.close()

PYCODE
end

execute "restart_zookeeper_health" do
  command "sudo supervisorctl restart zookeeper_health_server:"
  action :nothing
end


 
cookbook_file "/var/zookeeper_service.py" do
  source "zookeeper_service.py"
  mode "700"
  notifies :run, "execute[restart_zookeeper_health]"
  #notifies :restart, resources(:service => "supervisord")
end

template "/etc/supervisor/conf.d/supervisord.zookeeper.health.include.conf" do
  path "/etc/supervisor/conf.d/supervisord.zookeeper.health.include.conf"
  source "supervisord.zookeeper.health.include.conf.erb"
  owner "root"
  group "root"
  mode "700"
  notifies :restart, resources(:service => "supervisord"), :immediately 
end
service "supervisord"

