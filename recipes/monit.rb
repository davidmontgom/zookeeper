service "monit"
template "/etc/monit/conf.d/zookeeper.conf" do
  path "/etc/monit/conf.d/zookeeper.conf"
  source "monit.zookeeper.conf.erb"
  owner "root"
  group "root"
  mode "0755"
  notifies :restart, resources(:service => "monit")
end