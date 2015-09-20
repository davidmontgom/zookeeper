service "monit"
template "/etc/monit/conf.d/zookeeper.health.conf" do
  path "/etc/monit/conf.d/zookeeper.health.conf"
  source "monit.zookeeper.health.conf.erb"
  owner "root"
  group "root"
  mode "0755"
  notifies :restart, resources(:service => "monit")
end