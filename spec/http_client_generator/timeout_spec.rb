# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'timeout DSL' do
  it 'does not call timeout when no timeout is configured' do
    http_client = stub_http_response
    client = build_client do
      get :user
    end

    client.get_user

    expect(http_client).not_to have_received(:timeout)
    expect(http_client).to have_received(:get).with('https://api.example.test/user')
  end

  it 'applies a scoped global timeout' do
    http_client = stub_http_response
    client = build_client do
      timeout 5

      get :user
    end

    client.get_user

    expect(http_client).to have_received(:timeout).with(5)
    expect(http_client.timeout_client).to have_received(:get).with('https://api.example.test/user')
  end

  it 'applies a scoped per-operation timeout' do
    http_client = stub_http_response
    client = build_client do
      timeout connect: 1, read: 5, write: 2

      get :user
    end

    client.get_user

    expect(http_client).to have_received(:timeout).with(connect: 1, read: 5, write: 2)
    expect(http_client.timeout_client).to have_received(:get).with('https://api.example.test/user')
  end

  it 'lets a resource timeout override a scoped timeout' do
    http_client = stub_http_response
    client = build_client do
      timeout 5

      get :user, timeout: 2
    end

    client.get_user

    expect(http_client).to have_received(:timeout).with(2)
  end

  it 'lets a per-call timeout override a resource timeout' do
    http_client = stub_http_response
    client = build_client do
      timeout 5

      get :user, timeout: 2
    end

    client.get_user(timeout: 1)

    expect(http_client).to have_received(:timeout).with(1)
  end

  it 'supports null timeout mode' do
    http_client = stub_http_response
    client = build_client do
      timeout :null

      get :user
    end

    client.get_user

    expect(http_client).to have_received(:timeout).with(:null)
  end

  it 'lets namespace blocks inherit parent timeouts' do
    http_client = stub_http_response
    client = build_client do
      timeout 5

      namespace do
        get :user
      end
    end

    client.get_user

    expect(http_client).to have_received(:timeout).with(5)
  end

  it 'lets namespace blocks override parent timeouts' do
    http_client = stub_http_response
    client = build_client do
      timeout 5

      namespace do
        timeout read: 3

        get :user
      end
    end

    client.get_user

    expect(http_client).to have_received(:timeout).with(read: 3)
  end

  it 'does not expose per-call timeout as a rest arg for plugs' do
    seen_rest_args = []
    stub_http_response

    client = build_client do
      req_plug lambda { |request|
        seen_rest_args << request.rest_args
        request
      }

      get :user
    end

    client.get_user(timeout: 1, request_id: 'request-1')

    expect(seen_rest_args).to eq([{ request_id: 'request-1' }])
  end

  it 'accepts frozen timeout hashes without mutating them' do
    timeout_options = { read: 1 }.freeze
    http_client = stub_http_response

    client = build_client do
      get :user, timeout: timeout_options
    end

    client.get_user

    expect(timeout_options).to eq(read: 1)
    expect(http_client).to have_received(:timeout).with(read: 1)
  end

  it 'raises for invalid timeout values in the DSL' do
    expect do
      build_client do
        timeout '5'

        get :user
      end
    end.to raise_error(ArgumentError, 'Use timeout(global), timeout(:null), or timeout(connect: x, read: y, write: z).')
  end

  it 'raises for invalid per-operation timeout keys' do
    expect do
      build_client do
        get :user, timeout: { open: 1 }
      end
    end.to raise_error(ArgumentError, 'Unknown timeout option(s): open.')
  end

  it 'raises for invalid per-call timeout values' do
    stub_http_response
    client = build_client do
      get :user
    end

    expect { client.get_user(timeout: false) }.to raise_error(
      ArgumentError,
      'Use timeout(global), timeout(:null), or timeout(connect: x, read: y, write: z).'
    )
  end

  def build_client(&resources_block) # rubocop:disable Metrics/MethodLength
    client = Module.new do
      include HttpClientGenerator
    end

    url_helper = Module.new do
      include HttpClientGenerator::UrlBuilder

      def user(_options = {})
        'https://api.example.test/user'
      end
    end

    client.const_set(:UrlHelper, url_helper)
    client.resources(&resources_block)
    client.url_helper(url_helper)
    client
  end

  def stub_http_response # rubocop:disable Metrics/AbcSize
    http_client = double('HTTP::Client')
    timeout_client = double('HTTP::Client')
    response = double('HTTP::Response', status: double(code: 200), to_s: 'ok')

    allow(http_client).to receive(:timeout).and_return(timeout_client)
    allow(http_client).to receive(:get).and_return(response)
    allow(timeout_client).to receive(:get).and_return(response)

    allow(http_client).to receive(:timeout_client).and_return(timeout_client)
    allow(HTTP).to receive(:[]).and_return(http_client)

    http_client
  end
end
# rubocop:enable Metrics/BlockLength
