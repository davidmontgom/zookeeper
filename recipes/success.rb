bash "zookeeper_ok" do
  user "root"
  code <<-EOH
  touch /var/chef/cache/zookeeper.ok
  EOH
  action :run
  not_if {File.exists?("/var/chef/cache/zookeeper.ok")}
end