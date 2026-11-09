# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'http'

RSpec.describe 'request/response body safety' do
  let(:sent_bodies) { [] }

  describe 'key transformation collisions' do
    it 'raises when two response keys underscore to the same key with different values' do
      stub_post('{"availableBalance":"1000.00","available_balance":"0.00"}')

      client = build_client do
        resp_plug :enforce_json_response
        resp_plug :underscore_response
        post :user
      end

      expect { client.post_user }
        .to raise_error(client::RequestError, 'Key collision: multiple keys map to :available_balance')
    end

    it 'raises regardless of key order in the response document' do
      stub_post('{"available_balance":"0.00","availableBalance":"1000.00"}')

      client = build_client do
        resp_plug :enforce_json_response
        resp_plug :underscore_response
        post :user
      end

      expect { client.post_user }.to raise_error(client::RequestError, /:available_balance/)
    end

    it 'raises on collisions nested inside arrays' do
      stub_post('{"items":[{"fooBar":1,"foo_bar":2}]}')

      client = build_client do
        resp_plug :enforce_json_response
        resp_plug :underscore_response
        post :user
      end

      expect { client.post_user }.to raise_error(client::RequestError, /:foo_bar/)
    end

    it 'tolerates duplicate spellings that carry the same value' do
      stub_post('{"fooBar":1,"foo_bar":1}')

      client = build_client do
        resp_plug :enforce_json_response
        resp_plug :underscore_response
        post :user
      end

      expect(client.post_user).to eq(foo_bar: 1)
    end

    it 'raises before sending when two request body keys camelize to the same key' do
      stub_post('{}')

      client = build_client do
        req_plug :camelize_body
        post :user
      end

      expect { client.post_user(body: { amount_atomic: 100_000, 'amountAtomic' => 5 }) }
        .to raise_error(client::RequestError, 'Key collision: multiple keys map to :amountAtomic')
      expect(sent_bodies).to be_empty
    end

    it 'does not include values in the collision error message' do
      stub_post('{"secretToken":"s3cr3t","secret_token":"other"}')

      client = build_client do
        resp_plug :enforce_json_response
        resp_plug :underscore_response
        post :user
      end

      expect { client.post_user }
        .to raise_error(client::RequestError) { |e| expect(e.message).not_to include('s3cr3t') }
    end
  end

  describe ':validate_request' do
    let(:schema_helper) do
      Module.new do
        def self.post_user(body)
          if body[:title].is_a?(String)
            Result.new(true, { title: body[:title], amount: Integer(body[:amount]) })
          else
            Result.new(false, { title: ['is not a string'] })
          end
        end
      end
    end

    before do
      stub_const('Result', Struct.new(:valid, :payload) do
        def value_or
          valid ? payload : yield(payload)
        end
      end)
    end

    it 'sends the validated body instead of the original one' do
      stub_post('{}')
      helper = schema_helper

      client = build_client do
        req_plug :validate_request, schema_helper: helper
        post :user
      end

      client.post_user(body: { title: 'x', amount: '5', role: 'admin' })

      expect(JSON.parse(sent_bodies.last, symbolize_names: true)).to eq(title: 'x', amount: 5)
    end

    it 'raises and sends nothing when validation fails' do
      stub_post('{}')
      helper = schema_helper

      client = build_client do
        req_plug :validate_request, schema_helper: helper
        post :user
      end

      expect { client.post_user(body: { title: 1, amount: '5' }) }
        .to raise_error(client::RequestError, /is not a string/)
      expect(sent_bodies).to be_empty
    end

    it 'passes the body through when there is no schema for the resource' do
      stub_post('{}')
      helper = Module.new

      client = build_client do
        req_plug :validate_request, schema_helper: helper
        post :user
      end

      client.post_user(body: { anything: 'goes' })

      expect(JSON.parse(sent_bodies.last, symbolize_names: true)).to eq(anything: 'goes')
    end
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

  def stub_post(response_body)
    response = double('HTTP::Response', status: double(code: 200), to_s: response_body)
    http_client = double('HTTP::Client')
    allow(http_client).to receive(:post) do |_url, options = {}|
      sent_bodies << options[:body]
      response
    end
    allow(HTTP).to receive(:[]).and_return(http_client)
  end
end
