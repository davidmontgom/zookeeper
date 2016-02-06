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
            node = node = '%s-%s-%s-%s-%s-%s' % (self.server_type,self.slug,self.datacenter,self.environment,self.location,self.cluster_slug)
        if self.cluster_slug=="nocluster" and self.shard!=None:
            node = node = '%s-%s-%s-%s-%s-%s' % (self.server_type,self.slug,self.datacenter,self.environment,self.location,self.shard)
        if self.cluster_slug!="nocluster" and self.shard!=None:
            node = node = '%s-%s-%s-%s-%s-%s-%s' % (self.server_type,self.slug,self.datacenter,self.environment,self.location,self.cluster_slug,self.shard)
            
        self.path = '/%s/' % (node)
        
        return self.path
        
    def get_address_list(self):
        
        addresses = self.zk.children(self.path)
        self.addresses_list = list(set(addresses))
        
        return self.addresses_list 
    
    def close(self):
        
        self.zk.close()
        
        