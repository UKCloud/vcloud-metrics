#!/usr/bin/env ruby

require 'sinatra/base'
require 'json'
require 'rest-client'
require 'xmlsimple'

class VCloudStats < Sinatra::Base
  set :sessions, true

  get '/' do
    erb :index
  end

  get '/*' do
    redirect to('/')
  end

  post "/stats" do
    request.body.rewind  # in case someone already read it
    data = JSON.parse request.body.read

    # First authenticate with vCloud Director API
    begin
      vcloud_session = RestClient::Resource.new("#{data['vcd_api_url']}/sessions",
                                                "#{data['vcd_username']}",
                                                data['vcd_password'])
      auth = vcloud_session.post '', :accept => 'application/*+xml;version=5.6'
      auth_token = auth.headers[:x_vcloud_authorization]
    rescue => e
      halt 401, {'Content-Type' => 'text/json'}, e.to_json
    end

    vm_queue = []

    # Now use the query API to retrieve a list of VMs
    query_url = "#{data['vcd_api_url']}/query?type=vm"
    loop do

      begin
        response = RestClient.get query_url,
                                  # :params => { :type => 'vm' },
                                  'x-vcloud-authorization' => auth_token,
                                  :accept => 'application/*+xml;version=5.6'
      rescue => e
        halt 500, {'Content-Type' => 'text/json'}, e.to_json
      end

      parsed = XmlSimple.xml_in(response.to_str)

      # For each VM, call the /api/metrics/current API endpoint if it is not
      # a vApp Template: test for 'catalogName' property existing.
      parsed['VMRecord'].each do |vm|
        if vm['catalogName'].nil?
          # puts "Found #{vm['name']}"
          vm_queue << { 'name' => vm['name'], 'url' => "#{vm['href']}/metrics/current" }
        end
      end

      # Check for additional pages of results
      found_next_page = false

      parsed['Link'].each do |link|
        if link['rel'] == "nextPage"
          found_next_page = true
          query_url = link['href']
        end
      end 
    
      break unless found_next_page == true
    end

    stats_output = []

    vm_queue.each do |vm|
      begin
        response = RestClient.get vm['url'],
                                  'x-vcloud-authorization' => auth_token,
                                  :accept => 'application/*+xml;version=5.6'
      rescue => e
        halt 500, {'Content-Type' => 'text/json'}, e.to_json
      end
      stats = XmlSimple.xml_in(response.to_str)

      # For each VM metric, add the hostname and append to the output array
      stats['Metric'].each do |metric|
        metric['vm_name'] = vm['name']
        stats_output << metric
      end
    end

    [ 200, { 'Content-Type' => 'text/json' }, stats_output.to_json ]
  end

  # start the server if ruby file executed directly
  run! if app_file == $0
end
