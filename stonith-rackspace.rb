#!/usr/bin/env ruby
#
# External STONITH module for Rackspace Cloud (NextGen / v2 only)
#
# Author: Doug Neal <doug@neal.me.uk>
# License: GNU General Public License (GPL)
#
# References:
#   http://www.linux-ha.org/ExternalStonithPlugins
#

require 'rubygems'
require 'socket'
require 'fog'

def log(level, message)
  case level
  when 'crit','err','warn','warning','notice','info','debug'
    system('ha_log.sh', level, message)
  else
    system('ha_log.sh', 'notice', message)
  end
end

def find_server(server_name)
  if server_name == nil
    log('err', 'No server specified')
    exit 1
  end

  if ENV['RSC_USERNAME'] == nil
    log('err', 'RSC_USERNAME required in environment, but not set')
    exit 1
  end

  if ENV['RSC_REGION'] == nil
    log('err', 'RSC_REGION required in environment, but not set')
    exit 1
  end

  if ENV['RSC_APIKEY'] == nil
    log('err', 'RSC_APIKEY required in environment, but not set')
    exit 1
  end


  begin
    log('debug', "Attempting to authenticate to Rackspace API with account #{ENV['RSC_USERNAME']} in region #{ENV['RSC_REGION']}")

    service = Fog::Compute.new({
      :provider           => 'rackspace',
      :rackspace_username => ENV['RSC_USERNAME'],
      :rackspace_api_key  => ENV['RSC_APIKEY'],
      :version            => :v2,
      :rackspace_region   => ENV['RSC_REGION'],
      :rackspace_auth_url => 'https://lon.identity.api.rackspacecloud.com/v2.0'
       # ^^ shouldn't have to do this - it's a bug in Fog ^^
    })


  rescue Excon::Errors::Unauthorized => error
    log('err', "Authentication failure for account #{ENV['RSC_USERNAME']} in region #{ENV['RSC_REGION']}")
    exit 1

  rescue Excon::Errors::SocketError => error
    log('err', "Couldn't establish a connection to the identity service: #{error}")
    exit 1
  end

  log('debug', "Enumerating servers")

  servers = service.servers

  if servers.empty?
    log('debug', 'Server enumeration found no servers')
    return nil
  end

  log('debug', "Looking for '#{server_name}'")
  return servers.find { |s| s.name == server_name }
end

def reset(server)
  if server.state != 'ACTIVE'
    log('notice', "Server #{server.name} state is #{server.state} - no action required")
    return true
  
  else
    log('debug', "Server state is ACTIVE, sending reset command")
    #begin
      server.reboot
    #rescue ...

    #end

  end
end

def status(node)
end

# TODO don't fully understand this yet
# This is where you return an XML document describing the parameters (environment variables) that the plugin takes

def getinfo_xml
#puts <<eos
#<?xml version="1.0"?>
#<parameters>
#
#</parameters>
#eos
end

operation = ARGV[0]
target = ARGV[1]

case operation
  when nil
    log('err', 'No command specified')
    exit 1

  when 'reset', 'on'
    server = find_server(target)

    if server == nil
      log('err', "Server '#{target}' not found")
      exit 1
    end
    
    log('notice', "Fencing server '#{server.name}'")
    server.reboot

    #elsif server.state != server.ACTIVE
    #  log('debug', "Server '#{server_name}' was not found in an ACTIVE state (state was: #{server.state})")
    #  return true
    #else
    puts reset(server)

  when 'status'
    server = find_server(target) 
    puts status(server)

  when 'gethosts'
    puts Socket.gethostname

  when 'getconfignames'
    # Output a list of names of environment variables required to configure the operation of this agent
    puts "RSC_REGION\nRSC_USERNAME\nRSC_APIKEY\nRSC_SERVERNAME"

  when 'getinfo-devid'
    puts "STONITH via Rackspace Cloud API"

  when 'getinfo-devname'
    puts "STONITH via Rackspace Cloud API"

  when 'getinfo-devdescr'
    puts "STONITH via Rackspace Cloud API"

  when 'getinfo-devurl'
    puts "http://www.rackspace.com/"

  when 'getinfo-xml'
    devinfo_xml

  else
    log('err', "Command #{operation} not implemented")
    exit 1


  exit 0
end


