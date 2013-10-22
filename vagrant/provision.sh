#!/bin/bash

rpm -U https://dl.fedoraproject.org/pub/epel/6Server/x86_64/epel-release-6-8.noarch.rpm
yum -y groupinstall "Development tools"
yum -y install libyaml tk
rpm -U http://repository.kestrel.bjsscloud.com/yum/ruby1.9-1.9.3.448-1.el6.x86_64.rpm
gem1.9 install bundler

