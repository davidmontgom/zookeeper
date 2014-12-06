data_bag("my_data_bag")
db = data_bag_item("my_data_bag", "my")
aws = db[ node.chef_environment]['aws']
aws_access_key_id = aws['AWS_ACCESS_KEY_ID']
aws_secret_access_key = aws['AWS_SECRET_ACCESS_KEY']
zone_id = aws['route53']['zone_id']
riak_domain = db[node.chef_environment]['riak']['domain']['private']

if node.has_key?("ec2") 
    public_hostname = node[:ec2][:public_hostname]
    private_hostname = node[:ec2][:hostname]
    private_ip_address = node[:ipaddress]
    public_ip_address = node[:ec2][:public_ipv4]
    rtype = "A"
    dns = private_ip_address
else
    ipaddress = node[:ipaddress]
    dns = ipaddress
    rtype = "A"
end

easy_install_package "boto" do
  action :install
end

script "r53" do
  interpreter "python"
  user "root"
code <<-PYCODE
from boto.route53.connection import Route53Connection
from boto.route53.record import ResourceRecordSets
aws_access_key_id = "#{aws_access_key_id}"
aws_secret_access_key = "#{aws_secret_access_key}"
zone_id = "#{zone_id}"
weight = '1'
sub_domain = "#{riak_domain}" + '.'
dns = "#{dns}"
identifier = dns.replace('-','').replace('.','')
conn = Route53Connection(aws_access_key_id, aws_secret_access_key)
changes = ResourceRecordSets(conn, zone_id)
change = changes.add_change("CREATE",sub_domain, "#{rtype}", ttl=60, weight=weight, identifier=identifier)
change.add_value(dns)
changes.commit()
PYCODE
  not_if {File.exists?("#{Chef::Config[:file_cache_path]}/r53lock")}
end

file "#{Chef::Config[:file_cache_path]}/r53lock" do
  owner "root"
  group "root"
  mode "0755"
  action :create
end






