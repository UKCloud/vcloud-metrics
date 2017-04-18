#!/usr/bin/env ruby

require 'sinatra/base'
require 'json'
require 'rest-client'
require 'xmlsimple'
require 'thread'

module MyHelpers
  def execute_query(auth_token, vm)
    begin
      STDOUT.puts "Getting Metrics For VM #{vm['name']}: #{vm['url']} VDC: #{vm['vdc']}"
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
    end
  end

end



class VCloudStats < Sinatra::Base
  helpers MyHelpers
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
      STDOUT.puts "Logging In To #{data['vcd_api_url']}"
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
        STDOUT.puts "Executing Query: #{query_url}"
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
        if vm['catalogName'].nil? && vm['status'] == "POWERED_ON"
          vm_queue << { 'name' => vm['name'], 'url' => "#{vm['href']}/metrics/current", 'vdc' => vm['vdc'] }
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
    t1 = Time.now

    work_q = Queue.new
    vm_queue.map {|vm| work_q.push(vm)}

    MAX_THREADS = 20

    workers = (1..MAX_THREADS).map do
      Thread.new do
        begin
          while vm = work_q.pop(true)
            stats_output << execute_query(auth_token, vm)
          end
        rescue ThreadError
        end
      end
    end; "ok"
    workers.map(&:join); "ok"

       #stats_output << metric
 #   end


    t2 = Time.now
    STDOUT.puts "\nProcessed #{vm_queue.length} vm records in #{t2-t1} seconds"
    [ 200, { 'Content-Type' => 'text/json' }, stats_output.to_json ]
  end

  # start the server if ruby file executed directly
  run! if app_file == $0
end



