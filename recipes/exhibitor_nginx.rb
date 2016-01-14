template "/etc/nginx/sites-available/exhibitor.nginx.conf" do
  path "/etc/nginx/sites-available/exhibitor.nginx.conf"
  source "exhibitor.nginx.conf.erb"
  owner "root"
  group "root"
  mode "0644"
  notifies :reload, resources(:service => "nginx")
  #variables :nginx_port => nginx_port, :uwsgi_port => uwsgi_port
end

link "/etc/nginx/sites-enabled/exhibitor.nginx.conf" do
  to "/etc/nginx/sites-available/exhibitor.nginx.conf"
end
service "nginx"