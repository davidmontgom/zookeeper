import argparse
import os
import zc.zk
import logging 
import json
logging.basicConfig()
import paramiko
import dns.resolver
import subprocess


class zookeeper(object):
    
    def __init__(self,args):
        
        self.server_type = args.server_type
        self.username = args.username
        self.ip_address = args.ip_address
        self.slug = args.slug
        self.datacenter = args.datacenter
        self.environment = args.environment
        self.location = args.location
        self.cluster_slug = args.cluster_slug
        self.shard = args.shard
        self.zk_count = args.zk_count
        self.zk_hostname = args.zk_hostname
        self.keypair = args.keypair

    def get_zk_hostname(self):
        
        self.zookeeper_hosts = []
        for i in xrange(int(self.zk_count)):
            self.zookeeper_hosts.append( "%s-%s" % (i+1,self.zk_hostname) )
            
    def get_zk_ip_address(self):
        
        
        self.zookeeper_ip_address_list = []
        for aname in self.zookeeper_hosts:
          try:
              data =  dns.resolver.query(aname, 'A')
              self.zookeeper_ip_address_list.append(data[0].to_text())
          except:
              print 'ERROR, dns.resolver.NXDOMAIN',aname
              
        return self.zookeeper_ip_address_list
    
    def get_conn(self):
        
        self.get_zk_hostname()
        self.get_zk_ip_address()
        zk_host_list = []
        for zk_host in self.zookeeper_ip_address_list:
            zk_host_list.append(zk_host+':2181')

        zk_host_str = ','.join(zk_host_list)  
        
        try:  
            zk = zc.zk.ZooKeeper(zk_host_str)
        except:
            zk = None 
        self.zk =zk
        
        return zk

    def get_path(self):
        
        if self.cluster_slug=="nocluster" and self.shard==None:
            node = '%s-%s-%s-%s-%s' % (self.server_type,self.slug,self.datacenter,self.environment,self.location)
        if self.cluster_slug!="nocluster" and self.shard==None:
            node  = '%s-%s-%s-%s-%s-%s' % (self.server_type,self.slug,self.datacenter,self.environment,self.location,self.cluster_slug)
        if self.cluster_slug=="nocluster" and self.shard!=None:
            node  = '%s-%s-%s-%s-%s-%s' % (self.server_type,self.slug,self.datacenter,self.environment,self.location,self.shard)
        if self.cluster_slug!="nocluster" and self.shard!=None:
            node  = '%s-%s-%s-%s-%s-%s-%s' % (self.server_type,self.slug,self.datacenter,self.environment,self.location,self.cluster_slug,self.shard)
            
        self.path = '/%s/' % (node)
        
        return self.path
    
    def get_zk_path(self):
           
        #if self.cluster_slug=="nocluster" and self.shard==None:
        node = '%s-%s-%s-%s-%s' % ('zookeeper',self.slug,self.datacenter,self.environment,self.location)
        #if self.cluster_slug!="nocluster" and self.shard==None:
        #    node = node = '%s-%s-%s-%s-%s-%s' % ('zookeeper',self.slug,self.datacenter,self.environment,self.location,self.cluster_slug)
          
        self.path = '/%s/' % (node)
        
        return self.path
        
    def get_address_list(self):
        
        addresses = self.zk.children(self.path)
        self.addresses_list = list(set(addresses))
        
        return self.addresses_list 
    
    def close(self):
        
        self.zk.close()
      
      
      
      
      
def iptables_remote(this_ip_address,ip_address_list,keypair,username,cmd_list=[]):
    
    if this_ip_address in ip_address_list:
        ip_address_list.remove(this_ip_address)
    
    for ip_address in ip_address_list:
       
        keypair_path = '/root/.ssh/%s' % keypair
        key = paramiko.RSAKey.from_private_key_file(keypair_path)
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(ip_address, 22, username=username, pkey=key)
        
        cmd = "/sbin/iptables -D INPUT -j LOGGING"
        stdin, stdout, stderr = ssh.exec_command(cmd)
        
        cmd = "iptables -C INPUT -s %s -j ACCEPT" % (this_ip_address)
        stdin, stdout, stderr = ssh.exec_command(cmd)
        error_list = stderr.readlines()
        if error_list:
            output = ' '.join(error_list)
            if output.find('iptables: Bad rule (does a matching rule exist in that chain?).')>=0: 
                cmd = "/sbin/iptables -A INPUT -s %s -j ACCEPT" % (this_ip_address)
                print cmd
                stdin, stdout, stderr = ssh.exec_command(cmd)
                cmd = "rm /var/chef/cache/unicast_hosts"
                stdin, stdout, stderr = ssh.exec_command(cmd)
        
        cmd = "iptables -C OUTPUT -d %s -j ACCEPT" % (this_ip_address)
        stdin, stdout, stderr = ssh.exec_command(cmd)
        error_list = stderr.readlines()
        if error_list:
            output = ' '.join(error_list)
            if output.find('iptables: Bad rule (does a matching rule exist in that chain?).')>=0:
                cmd = "/sbin/iptables -A OUTPUT -d %s -j ACCEPT" % (this_ip_address)
                print cmd
                stdin, stdout, stderr = ssh.exec_command(cmd)
                cmd = "/etc/init.d/iptables-persistent save" 
                stdin, stdout, stderr = ssh.exec_command(cmd)
                
        cmd = "/sbin/iptables -C INPUT -j LOGGING"
        stdin, stdout, stderr = ssh.exec_command(cmd)
        error_list = stderr.readlines()
        if error_list:
            output = ' '.join(error_list)
            if output.find('iptables: No chain/target/match by that name.')>=0:
                cmd = "/sbin/iptables -A INPUT -j LOGGING"
                print cmd
                stdin, stdout, stderr = ssh.exec_command(cmd)
                cmd = "/etc/init.d/iptables-persistent save" 
                stdin, stdout, stderr = ssh.exec_command(cmd)
        
        for cmd in cmd_list:
            stdin, stdout, stderr = ssh.exec_command(cmd)
            out = stdout.read()
            err = stderr.read()
        
        ssh.close()


def iptables_local(this_ip_address,ip_address_list):
    
    if this_ip_address in ip_address_list:
        ip_address_list.remove(this_ip_address)
    
    for ip_address in ip_address_list:     
        
        cmd = "/sbin/iptables -D INPUT -j LOGGING" 
        p = subprocess.Popen(cmd, shell=True,stderr=subprocess.STDOUT,stdout=subprocess.PIPE,executable="/bin/bash")
        
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
            
        
        cmd = "/sbin/iptables -C INPUT -j LOGGING" 
        p = subprocess.Popen(cmd, shell=True,stderr=subprocess.STDOUT,stdout=subprocess.PIPE,executable="/bin/bash")
        out = p.stdout.readline().strip()
        if out.find('iptables: No chain/target/match by that name.')>=0:
            cmd = "/sbin/iptables -A INPUT -j LOGGING"
            os.system(cmd)
    
  
        