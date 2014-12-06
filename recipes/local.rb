location = "local"
environment = "local"

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
file "#{Chef::Config[:file_cache_path]}/zookeeper_lock" do
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
