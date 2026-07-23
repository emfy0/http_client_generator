# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Metrics/BlockLength, Metrics/MethodLength
RSpec.describe 'response handling' do
  it 'runs response-head plugs with the status code before reading and parsing the body' do
    events = []
    statuses = []
    response = double('HTTP::Response', status: double(code: 202))
    allow(response).to receive(:to_s) do
      events << :body_read
      '{"accepted":true}'
    end
    stub_response(response)

    client = build_client do
      resp_head_plug lambda { |request|
        statuses << request.response_status
        events << :head_plug
        request
      }
      resp_plug lambda { |request|
        events << :body_plug
        request.response_body = JSON.parse(request.response_body, symbolize_names: true)
        request
      }

      get :user
    end

    expect(client.get_user).to eq(accepted: true)
    expect(statuses).to eq([202])
    expect(events).to eq(%i[head_plug body_read body_plug])
  end

  it 'returns an unconsumed body stream after response-head plugs run' do
    statuses = []
    body = double('HTTP::Response::Body')
    allow(body).to receive(:each).and_yield('first').and_yield('second')
    response = double('HTTP::Response', status: double(code: 200), body: body)
    expect(response).not_to receive(:to_s)
    stub_response(response)

    client = build_client do
      resp_head_plug lambda { |request|
        statuses << request.response_status
        request
      }

      get :user, stream: true
    end

    stream = client.get_user
    chunks = []
    stream.each { |chunk| chunks << chunk }

    expect(stream).to equal(body)
    expect(statuses).to eq([200])
    expect(chunks).to eq(%w[first second])
  end

  it 'rejects streaming resources with matching response body plugs' do
    expect do
      build_client do
        resp_plug ->(request) { request }
        get :user, stream: true
      end
    end.to raise_error(ArgumentError, 'Streaming resource :user cannot use response body plugs')
  end

  it 'allows streaming resources when response body plugs do not match them' do
    expect do
      build_client do
        resp_plug ->(request) { request }, except: :user
        get :user, stream: true
      end
    end.not_to raise_error
  end

  def build_client(&resources_block)
    client = Module.new do
      include HttpClientGenerator
    end

    url_helper = Module.new do
      include HttpClientGenerator::UrlBuilder

      def user(_options = {})
        'https://api.example.test/user'
      end
    end

    client.resources(&resources_block)
    client.url_helper(url_helper)
    client
  end

  def stub_response(response)
    http_client = double('HTTP::Client')
    allow(http_client).to receive(:get).and_return(response)
    allow(HTTP).to receive(:[]).and_return(http_client)
  end
end
# rubocop:enable Metrics/BlockLength, Metrics/MethodLength
