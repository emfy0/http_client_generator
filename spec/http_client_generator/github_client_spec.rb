# frozen_string_literal: true

require 'spec_helper'
require 'uri'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'GitHub client from the README example' do
  before do
    stub_const('GitHub', Module.new)

    GitHub.module_eval(<<~'RUBY', __FILE__, __LINE__ + 1)
      include HttpClientGenerator

      Configuration = Struct.new(:base_url, :access_token, keyword_init: true)

      class InvalidConfigurationError < Error
        ACCESS_TOKEN_ERROR = 'Access token should be a non-empty String.'
        BASE_URL_ERROR = 'Base URL should be a non-empty String.'
      end

      module UrlHelper
        include HttpClientGenerator::UrlBuilder

        def user(_options = {})
          "#{config.base_url}/user"
        end

        def repository(options)
          "#{config.base_url}/repos/#{options.fetch(:owner)}/#{options.fetch(:repo)}"
        end

        def repository_issues(options)
          build_url(
            url: "#{config.base_url}/repos/#{options.fetch(:owner)}/#{options.fetch(:repo)}/issues",
            query: options.slice(:state, :labels, :since, :per_page, :page),
          )
        end

        def issue(options)
          issue_number = options[:issue_number]
          path = "#{config.base_url}/repos/#{options.fetch(:owner)}/#{options.fetch(:repo)}/issues"

          issue_number ? "#{path}/#{issue_number}" : path
        end

        private

        def config = GitHub.config

        def build_url(url:, query: {})
          uri = URI(url)
          query_values = query.compact.transform_keys { |key| HttpClientGenerator::Inflector.camelize_lower(key) }

          uri.query = URI.encode_www_form(query_values) if query_values.any?
          uri.to_s
        end
      end

      resources do
        req_plug :set_request_id, :x_request_id
        req_plug :set_header, header: :accept, value: "application/vnd.github+json"
        req_plug :set_header, header: :x_github_api_version, value: "2022-11-28"
        req_plug :set_header,
          header: :authorization,
          value: -> { "Bearer #{GitHub.config.access_token}" }

        req_plug :camelize_body

        resp_plug :enforce_json_response
        resp_plug :underscore_response

        get :user
        get :repository
        get :repository_issues
        post :issue
        patch :issue
      end

      url_helper UrlHelper

      process_config do |config|
        validation_errors = []

        unless config.access_token.is_a?(String) && !config.access_token.empty?
          validation_errors << InvalidConfigurationError::ACCESS_TOKEN_ERROR
        end

        unless config.base_url.is_a?(String) && !config.base_url.empty?
          validation_errors << InvalidConfigurationError::BASE_URL_ERROR
        end

        raise InvalidConfigurationError, validation_errors.join(" ") if validation_errors.any?
      end
    RUBY

    GitHub.configure do |config|
      config.base_url = 'https://api.github.test'
      config.access_token = 'github-token'
    end
  end

  it 'validates configuration' do
    expect do
      GitHub.configure do |config|
        config.base_url = nil
        config.access_token = ''
      end
    end.to raise_error(
      GitHub::InvalidConfigurationError,
      'Access token should be a non-empty String. Base URL should be a non-empty String.'
    )
  end

  it 'generates a GET request for the authenticated user' do
    http_client = stub_http_response({ 'login' => 'octocat' })

    response = GitHub.get_user(request_id: 'request-1')

    expect(response).to eq(login: 'octocat')
    expect(HTTP).to have_received(:[]).with(
      accept: 'application/vnd.github+json',
      content_type: 'application/json',
      x_request_id: 'request-1',
      x_github_api_version: '2022-11-28',
      authorization: 'Bearer github-token'
    )
    expect(http_client).to have_received(:get).with('https://api.github.test/user')
  end

  it 'builds repository issue URLs with camelized query parameters' do
    http_client = stub_http_response([{ 'html_url' => 'https://github.test/issues/1' }])

    response = GitHub.get_repository_issues(
      { owner: 'rails', repo: 'rails', state: 'open', per_page: 10, page: nil },
      request_id: 'request-2'
    )

    expect(response).to eq([{ html_url: 'https://github.test/issues/1' }])
    expect(http_client).to have_received(:get).with(
      'https://api.github.test/repos/rails/rails/issues?state=open&perPage=10'
    )
  end

  it 'camelizes JSON request bodies when creating an issue' do
    http_client = stub_http_response({ 'html_url' => 'https://github.test/issues/42' })

    response = GitHub.post_issue(
      { owner: 'octo-org', repo: 'octo-repo' },
      body: {
        title: 'Bug report',
        body: 'Steps to reproduce...',
        assignee_ids: [1, 2],
        milestone: {
          due_on: '2026-06-23'
        },
        labels: [
          { label_id: 10 }
        ]
      },
      request_id: 'request-3'
    )

    expected_body = {
      title: 'Bug report',
      body: 'Steps to reproduce...',
      assigneeIds: [1, 2],
      milestone: {
        dueOn: '2026-06-23'
      },
      labels: [
        { labelId: 10 }
      ]
    }.to_json

    expect(response).to eq(html_url: 'https://github.test/issues/42')
    expect(http_client).to have_received(:post).with(
      'https://api.github.test/repos/octo-org/octo-repo/issues',
      body: expected_body
    )
  end

  it 'uses the issue number in PATCH issue URLs' do
    http_client = stub_http_response({ 'state' => 'closed' })

    response = GitHub.patch_issue(
      { owner: 'octo-org', repo: 'octo-repo', issue_number: 42 },
      body: { state: 'closed' },
      request_id: 'request-4'
    )

    expect(response).to eq(state: 'closed')
    expect(http_client).to have_received(:patch).with(
      'https://api.github.test/repos/octo-org/octo-repo/issues/42',
      body: '{"state":"closed"}'
    )
  end

  def stub_http_response(response_body)
    http_client = instance_double('HTTP::Client')

    allow(HTTP).to receive(:[]).and_return(http_client)
    %i[get post patch].each do |verb|
      allow(http_client).to receive(verb).and_return(response_body.to_json)
    end

    http_client
  end
end
# rubocop:enable Metrics/BlockLength
