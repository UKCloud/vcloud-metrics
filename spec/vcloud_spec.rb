require File.expand_path '../spec_helper.rb', __FILE__

describe "vCloud Metrics Microservice" do
  before(:all) do

    @params = {
      :vcd_api_url => "https://#{ENV['VCD_API_HOST']}/api",
      :vcd_username => "#{ENV['VCD_USERNAME']}@#{ENV['VCD_ORG']}",
      :vcd_password => ENV['VCD_PASSWORD']
    }


    @results = post '/stats', @params.to_json

  end

  it "prints a help message on GET" do
    get '/'
    # Rspec 2.x
    expect(last_response).to match(/Welcome to your vCloud Metrics Portal/)

  end


  it "gets some metrics" do

    expect(JSON.parse(@results.body)).to be_a Array
  end

  it "has metrics as a direct decendant in the array" do

    expect(JSON.parse(@results.body).first).to be_a Hash
  end
end
