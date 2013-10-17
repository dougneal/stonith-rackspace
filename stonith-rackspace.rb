#!/usr/bin/env ruby1.9
#
# External STONITH module for Rackspace Cloud (NextGen / v2 only)
#
# Author: Doug Neal <doug@neal.me.uk>
# License: GNU General Public License v2
#
#
# The STONITH interface is not documented and no guarantees are made as to this agent's adherence to it.
# Code here is based on inferences made from reading the source of other agents included with cluster-glue.
# 
#
#
# Set the following environment variables to configure the agent's operation:
#  RSC_USERNAME   (required)  Your Rackspace Cloud account username
#  RSC_APIKEY     (required)  Your Rackspace Cloud account API key
#  RSC_REGION     (required)  Region - DFW, ORD, LON or anything supported by Fog
#  RSC_AUTHURL    (optional)  Override the URL that you hit to authenticate against the API
#                             Fog should take care of this but doesn't always get it right
#                             UK endpoint: https://lon.identity.api.rackspacecloud.com/v1.1
# 
# To trace HTTP set the environment variable EXCON_DEBUG=1
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

def service_attach
  log('debug', "Attaching to Rackspace Cloud API service - sanity check ...")

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

  log('debug', "... OK")

  begin
    log('debug', "Attempting to authenticate to Rackspace API with account #{ENV['RSC_USERNAME']} in region #{ENV['RSC_REGION']}")

    service = Fog::Compute.new({
      :provider           => 'rackspace',
      :rackspace_username => ENV['RSC_USERNAME'],
      :rackspace_api_key  => ENV['RSC_APIKEY'],
      :version            => :v2,
      :rackspace_region   => ENV['RSC_REGION'],
      :rackspace_auth_url => ENV['RSC_AUTHURL']
      #:rackspace_auth_url => 'https://lon.identity.api.rackspacecloud.com/v2.0'
       # ^^ shouldn't have to do this - it's a bug in Fog ^^
    })

  rescue Excon::Errors::Unauthorized => error
    log('err', "Authentication failure for account #{ENV['RSC_USERNAME']} in region #{ENV['RSC_REGION']}")
    exit 1

  rescue Excon::Errors::SocketError => error
    log('err', "Couldn't establish a connection to the identity service: #{error}")
    exit 1
  end

  log('debug', 'Successfully attached to Rackspace Cloud API service')

  return service
end

def find_server(server_name)
  if server_name == nil
    log('err', 'No server specified')
    exit 1
  end

  service = service_attach

  log('debug', 'Enumerating servers')

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
    log('debug', "Server state is ACTIVE, sending reboot HARD command")
    begin
      reboot = server.reboot('HARD')
      log('debug', "Reboot command returned #{reboot}")
    rescue Exception => e
      log('error', "Reboot command encountered error: #{e.to_s}")
      exit 1
    end
  end

  return true
end

def status
  service = service_attach
  return (service != nil)
end

# TODO don't fully understand this yet
# This is where you return an XML document describing the parameters (environment variables) that the plugin takes

def getinfo_xml
puts <<xml
<?xml version="1.0"?>
<parameters>
  <parameter name="rsc_username" required="1">
    <content type="string" />
    <shortdesc lang="en">Rackspace Cloud account username</shortdesc>
    <longdesc lang="en">Rackpsace Cloud account username</longdesc>
  </parameter>

  <parameter name="rsc_apikey" required="1">
    <content type="string" />
    <shortdesc lang="en">Rackspace Cloud account API key</shortdesc>
    <longdesc lang="en">Rackspace Cloud account API key</longdesc>
  </parameter>

  <parameter name="rsc_region" required="1">
    <content type="string" />
    <shortdesc lang="en">Rackspace Cloud region - 3 letter short code</shortdesc>
    <longdesc lang="en">
      The 3-letter region code for your Rackspace Cloud account, e.g. DFW, ORD, LON
    </longdesc>
  </parameter>

  <parameter name="rsc_authurl">
    <content type="string" />
    <shortdesc lang="en">API endpoint for Rackspace Cloud identity service</shortdesc>
    <longdesc lang="en">
      API endpoint for Rackspace Cloud identity service

      The best endpoint should be determined by the region code, but this parameter
      is here in case you wish to override it

      Some versions of the Fog library do not always make the correct decision.
    </longdesc>
  </parameter>
</parameters>
xml
end

operation = ARGV[0]
target = ARGV[1]

case operation
  when nil
    log('err', 'No command specified')
    exit 1

  when 'reset', 'on'
    # The Rackspace Cloud API doesn't make a distinction between a reboot command and a power-on command
    # so we map both on to the same operation. The API doesn't provide a power-off command either, but
    # the STONITH interface doesn't require one
    server = find_server(target)

    if server == nil
      log('err', "Server '#{target}' not found")
      exit 1
    end
    
    log('notice', "Fencing server '#{server.name}'")
    reset(server)

  when 'status'
    # Command to retrieve the status of the STONITH device (NOT the server to be fenced)
    # We just check that we can reach the API endpoint and obtain an authentication token, then take no action
    if ! status
      exit 1
    end

  when 'gethosts'
    # Just print my own hostname. Other STONITH plugins that talk to virtualisation APIs do this.
    # I don't really know why at the moment.
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
    getinfo_xml

  else
    log('err', "Command #{operation} not implemented")
    exit 1


  exit 0
end


