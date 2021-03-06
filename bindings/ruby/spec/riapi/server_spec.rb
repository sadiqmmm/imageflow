ENV['RACK_ENV'] = 'test'

require 'rspec'
require 'imageflow'
require 'imageflow/riapi'

require 'rack/test'

describe 'Imageflow::Riapi::Server' do
  include Rack::Test::Methods

  def app
    Imageflow::Riapi::Server
  end

  it "says hello" do
    get '/tinypng'
    expect(last_response).to be_ok
    expect(last_response.content_type).to eq('image/png')
    expect(last_response.headers['X-CPU-TIME']).to match(/^[-+]?[0-9]*\.?[0-9]+$/)
  end

  it "downsamples a jpeg" do
    get '/jpeg32?width=8&height=8&precise_scaling_ratio=1'
    expect(last_response).to be_ok
    expect(last_response.content_type).to eq('image/jpeg')
    expect(last_response.headers['X-CPU-TIME']).to match(/^[-+]?[0-9]*\.?[0-9]+$/)
  end
end