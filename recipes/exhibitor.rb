

package "python-software-properties" do
  action :install
end

package "maven" do
  action :install
end

bash "install_exhibitor" do
  user "root"
  cwd "/var"
  code <<-EOH
    git clone https://github.com/Netflix/exhibitor.git
    cd exhibitor
    wget https://raw.github.com/Netflix/exhibitor/master/exhibitor-standalone/src/main/resources/buildscripts/standalone/maven/pom.xml
    mvn clean package
    cd /var/exhibitor/target
    cp exhibitor-*.jar exhibitor.jar
  EOH
  action :run
  not_if {File.exists?("/var/exhibitor")}
end

execute "restart_supervisorctl_exhibitor" do
  command "sudo supervisorctl restart exhibitor_server:"
  action :nothing
end

template "/etc/supervisor/conf.d/exhibitor.conf" do
  path "/etc/supervisor/conf.d/exhibitor.conf"
  source "supervisord.exhibitor.conf.erb"
  owner "root"
  group "root"
  mode "0755"
  #notifies :restart, resources(:service => "supervisord")
  notifies :run, "execute[restart_supervisorctl_exhibitor]"
end












