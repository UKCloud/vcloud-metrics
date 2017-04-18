require File.expand_path '../spec_helper.rb', __FILE__

describe "vCloud Metrics Microservice" do
  it "prints a help message on GET" do
    get '/'
    # Rspec 2.x
    expect(last_response).to match(/Welcome to your vCloud Metrics Portal/)

  end


  it "gets some metrics" do
    params = {
      :vcd_api_url => "https://#{ENV['VCD_API_HOST']}/api",
      :vcd_username => "#{ENV['VCD_USERNAME']}@#{ENV['VCD_ORG']}",
      :vcd_password => ENV['VCD_PASSWORD']
    }
    post '/stats', params.to_json

    expect(JSON.parse(last_response.body)).to be_a Array
  end
end
