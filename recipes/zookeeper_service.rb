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


#This is becuase aws uses SG
if datacenter!='aws'
  dc_cloud = data_bag_item("meta_data_bag", "#{datacenter}")
  keypair = dc_cloud[node.chef_environment]["keypair"]
  username = dc_cloud["username"]
end

#zookeeper_hosts = "1.#{subdomain}.#{domain}"

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

easy_install_package "dnspython" do
  action :install
end



if datacenter!='local' and datacenter!='aws'
  script "zookeeper_add" do
    interpreter "python"
    user "root"
  code <<-PYCODE
import paramiko
import subprocess
import os
import dns.resolver
import zc.zk
username='#{username}' 
zookeeper_hosts = []
zookeeper_ip_address_list = []
for i in xrange(int(#{required_count})):
    zookeeper_hosts.append("%s-#{full_domain}" % (i+1))
zk_host_list = []

for aname in zookeeper_hosts:
  try:
      data =  dns.resolver.query(aname, 'A')
      zk_host_list.append(data[0].to_text()+':2181')
      zookeeper_ip_address_list.append(data[0].to_text())
  except:
      print 'ERROR, dns.resolver.NXDOMAIN',aname
zk_host_str = ','.join(zk_host_list)    
    
ip_address_list = zookeeper_hosts
if len(ip_address_list)>0:
  for ip_address in ip_address_list:
    if ip_address != '#{node[:ipaddress]}':
      keypair_path = '/root/.ssh/#{keypair}'
      key = paramiko.RSAKey.from_private_key_file(keypair_path)
      ssh = paramiko.SSHClient()
      ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
      try:
        ssh.connect(ip_address, 22, username=username, pkey=key) 
        
        cmd = "iptables -C INPUT -s %s -j ACCEPT" % (ip_address)
        output_list, error_list = ssh.ssh_execute_command(cmd)
        output = ' '.join(output_list) + ' '.join(error_list)
        print 'output:',output
        if output.find('iptables: Bad rule (does a matching rule exist in that chain?).')>=0:
            cmd = "/sbin/iptables -A INPUT -s %s -j ACCEPT" % (ip_address)
            output_list, error_list = ssh.ssh_execute_command(cmd)
        
        cmd = "iptables -C OUTPUT -d %s -j ACCEPT" % (ip_address)
        output_list, error_list = ssh.ssh_execute_command(cmd)
        output = ' '.join(output_list) + ' '.join(error_list)
        print 'output:',output
        if output.find('iptables: Bad rule (does a matching rule exist in that chain?).')>=0:
            print 'OUTPUT',server_type, ip_address, output
            cmd = "/sbin/iptables -A OUTPUT -d %s -j ACCEPT" % (ip_address)
            output_list, error_list = ssh.ssh_execute_command(cmd)
        
        cmd = "/etc/init.d/iptables-persistent save" 
        stdin, stdout, stderr = ssh.exec_command(cmd)
        out = stdout.read()
        err = stderr.read()
        print "out--", out
      except:
        pass
      ssh.close()
      
      cmd = "iptables -C INPUT -s %s -j ACCEPT" % (ip_address)
      p = subprocess.Popen(cmd, shell=True,stderr=subprocess.STDOUT,stdout=subprocess.PIPE,executable="/bin/bash")
      out = p.stdout.readline().strip()
      if out.find('iptables: Bad rule (does a matching rule exist in that chain?).')>=0:
          cmd = "/sbin/iptables -A INPUT -s %s -j ACCEPT" % (ip_address)
          os.system(cmd)
          
      cmd = "iptables -C OUTPUT -d %s -j ACCEPT" % (ip_address)
      p = subprocess.Popen(cmd, shell=True,stderr=subprocess.STDOUT,stdout=subprocess.PIPE,executable="/bin/bash")
      out = p.stdout.readline().strip()
      if out.find('iptables: Bad rule (does a matching rule exist in that chain?).')>=0:
          cmd = "/sbin/iptables -A OUTPUT -d  %s -j ACCEPT" % (ip_address)
          os.system(cmd)
          
PYCODE
  end
end

script "zookeeper_files" do
  interpreter "python"
  user "root"
code <<-PYCODE
import json

zookeeper_hosts = []
for i in xrange(int(#{required_count})):
    zookeeper_hosts.append("%s-#{full_domain}" % (i+1))
zookeeper_hosts = ','.join(zookeeper_hosts)

f = open('/var/zookeeper_hosts.json','w')
f.write(zookeeper_hosts)
f.close()

f = open('/var/zookeeper_node_name.json','w')
f.write('#{node.name} #{node[:ipaddress]}')
f.close()

f = open('/var/zk_process_monitor_list.json','w')
f.write('#{zk_process_monitor_list}')
f.close()



PYCODE
end

execute "restart_zookeeper_health" do
  command "sudo supervisorctl restart zookeeper_health_server:"
  action :nothing
end
 
cookbook_file "/var/zookeeper_service.py" do
  source "zookeeper_service.py"
  mode 00744
  notifies :run, "execute[restart_zookeeper_health]"
  #notifies :restart, resources(:service => "supervisord")
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

