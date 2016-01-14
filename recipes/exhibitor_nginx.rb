server_type = node.name.split('-')[0]
slug = node.name.split('-')[1] 
datacenter = node.name.split('-')[2]
environment = node.name.split('-')[3]
location = node.name.split('-')[4]
cluster_slug = File.read("/var/cluster_slug.txt")
cluster_slug = cluster_slug.gsub(/\n/, "") 

zookeeper_server = data_bag_item("server_data_bag", "zookeeper")
if zookeeper_server[datacenter][environment][location].has_key?(cluster_slug)
  cluster_slug_zookeeper = cluster_slug
else
  cluster_slug_zookeeper = "nocluster"
end

if cluster_slug_zookeeper=="nocluster"
  subdomain = "zookeeper-#{slug}-#{datacenter}-#{environment}-#{location}"
else
  subdomain = "#{cluster_slug_zookeeper}-zookeeper-#{slug}-#{datacenter}-#{environment}-#{location}"
end
required_count = zookeeper_server[datacenter][environment][location][cluster_slug_zookeeper]['required_count']
full_domain = "#{subdomain}.#{domain}"

zookeeper_host = "1-#{full_domain}"

template "/etc/nginx/sites-available/exhibitor.nginx.conf" do
  path "/etc/nginx/sites-available/exhibitor.nginx.conf"
  source "exhibitor.nginx.conf.erb"
  owner "root"
  group "root"
  mode "0644"
  notifies :reload, resources(:service => "nginx")
  variables :zookeeper_host => zookeeper_host
end

link "/etc/nginx/sites-enabled/exhibitor.nginx.conf" do
  to "/etc/nginx/sites-available/exhibitor.nginx.conf"
end
service "nginx"