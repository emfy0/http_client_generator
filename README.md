# HttpClientGenerator

`http-client-generator` is a small Ruby DSL for building API clients on top of the
[`http`](https://github.com/httprb/http) gem.

You declare resources, attach request and response plugs, provide a URL helper,
and the gem generates class-level request methods such as `get_user`,
`post_issue`, or `patch_repository`.

## Installation

Add the gem to your application:

```ruby
gem 'http-client-generator'
```

Then run:

```sh
bundle install
```

## Usage

Define a client module, include `HttpClientGenerator`, declare resources, and
provide a URL helper module with methods that match each resource name.

This example sketches a small GitHub API client.

```ruby
require 'http_client_generator'
require 'zeitwerk'

Zeitwerk::Loader.for_gem.setup

module GitHub
  include HttpClientGenerator

  Configuration = Struct.new(:base_url, :access_token, keyword_init: true)

  class InvalidConfigurationError < Error
    ACCESS_TOKEN_ERROR = 'Access token should be a non-empty String.'
    BASE_URL_ERROR = 'Base URL should be a non-empty String.'
  end

  resources do
    req_plug :set_request_id, :x_request_id
    req_plug :set_header, header: :accept, value: 'application/vnd.github+json'
    req_plug :set_header, header: :x_github_api_version, value: '2022-11-28'
    req_plug :set_header,
      header: :authorization,
      value: -> { "Bearer #{GitHub.config.access_token}" }

    req_plug :camelize_body

    resp_plug :enforce_json_response
    resp_plug :underscore_response

    timeout connect: 2, read: 5, write: 5

    get :user
    get :repository
    get :repository_issues, timeout: 10
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

    raise InvalidConfigurationError, validation_errors.join(' ') if validation_errors.any?
  end
end
```

```ruby
require 'uri'

module GitHub
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
end
```

Configure the client before making requests:

```ruby
GitHub.configure do |config|
  config.base_url = 'https://api.github.com'
  config.access_token = ENV.fetch('GITHUB_TOKEN')
end
```

Then call generated methods. Method names are built from the HTTP verb and
resource name:

```ruby
GitHub.get_user

GitHub.get_user(timeout: 1)

GitHub.get_repository(owner: 'rails', repo: 'rails')

GitHub.get_repository_issues(
  { owner: 'rails', repo: 'rails', state: 'open', per_page: 10 },
  request_id: SecureRandom.uuid,
)

GitHub.post_issue(
  { owner: 'octo-org', repo: 'octo-repo' },
  body: {
    title: 'Bug report',
    body: 'Steps to reproduce...',
    labels: ['bug'],
  },
)

GitHub.patch_issue(
  { owner: 'octo-org', repo: 'octo-repo', issue_number: 42 },
  body: {
    state: 'closed',
  },
)
```

## Resources

Declare resources inside a `resources` block:

```ruby
resources do
  get :user
  post :issue
  put :repository
  patch :issue
end
```

Each resource generates a singleton method on the client module:

| Declaration | Generated method |
| --- | --- |
| `get :user` | `get_user` |
| `post :issue` | `post_issue` |
| `put :repository` | `put_repository` |
| `patch :issue` | `patch_issue` |

Generated methods accept URL options as the first positional argument, optional
`body:` and `timeout:` keywords, and any extra keyword arguments consumed by
plugs:

```ruby
Client.post_resource(
  { id: 1 },
  body: { name: 'Example' },
  timeout: 2,
  request_id: 'abc-123',
)
```

JSON is the default content type. Use `content_type: :text` for plain text
request bodies:

```ruby
resources do
  post :webhook_test, content_type: :text
end
```

## Timeouts

Timeouts mirror the `http` gem API. Use a numeric value for a global timeout,
per-operation values for connect/read/write limits, or `:null` to explicitly
disable timeout handling.

```ruby
resources do
  timeout 5

  get :user
  get :repository_issues, timeout: { read: 10 }

  namespace do
    timeout connect: 1, read: 3, write: 3

    post :issue
  end

  get :stream, timeout: :null
end
```

Timeout precedence, from highest to lowest:

1. Per-call `timeout:`
2. Resource-level `timeout:`
3. Current scoped `timeout`
4. No timeout configuration

```ruby
Client.get_user(timeout: 1)
Client.post_issue({ id: 1 }, body: { title: 'Bug' }, timeout: :null)
```

## URL Helpers

Register a URL helper with `url_helper`. The helper must respond to every
resource name and return a complete URL.

```ruby
module Client
  module UrlHelper
    include HttpClientGenerator::UrlBuilder

    def resource(options)
      "#{Client.config.base_url}/resources/#{options.fetch(:id)}"
    end
  end
end

Client.url_helper Client::UrlHelper
```

`HttpClientGenerator::UrlBuilder` extends the helper module so resource URLs can
be called by the generated client methods.

## Plugs

Plugs are objects that respond to `call(request)`. Request plugs run before the
HTTP request. Response plugs run after the response body is read.

```ruby
resources do
  req_plug :set_request_id, :x_request_id
  req_plug :set_bearer_token, from_arg: :access_token

  resp_plug :enforce_json_response
  resp_plug :underscore_response

  get :profile
end
```

Built-in request plugs:

| Plug | Purpose |
| --- | --- |
| `:set_request_id` | Sets a generated or provided request id header. |
| `:set_header` | Sets a static, dynamic, or argument-derived header. |
| `:set_bearer_token` | Sets `Authorization: Bearer ...` from an extra method argument. |
| `:camelize_body` | Camelizes JSON request body keys. |
| `:validate_request` | Validates request bodies with a schema helper. |

Built-in response plugs:

| Plug | Purpose |
| --- | --- |
| `:enforce_json_response` | Parses the response as JSON and raises on invalid JSON. |
| `:encode_json_response` | Parses JSON responses when possible and leaves invalid JSON unchanged. |
| `:underscore_response` | Underscores parsed response keys. |
| `:validate_response` | Validates parsed response bodies with a schema helper. |

Limit plugs to specific resources with `only:` or `except:`:

```ruby
resources do
  req_plug :camelize_body, only: %i[create_issue update_issue]
  resp_plug :enforce_json_response, except: :download_archive

  post :create_issue
  patch :update_issue
  get :download_archive, content_type: :text
end
```

You can also pass a callable plug:

```ruby
resources do
  req_plug ->(request) {
    request.headers[:user_agent] = 'my-client/1.0'
    request
  }

  get :user
end
```

## Configuration

The client module owns its configuration type. Define `Configuration`, then call
`configure`:

```ruby
module Client
  include HttpClientGenerator

  Configuration = Struct.new(:base_url, :access_token, keyword_init: true)

  process_config do |config|
    raise Error, 'Missing base URL' unless config.base_url.is_a?(String)
  end
end

Client.configure do |config|
  config.base_url = 'https://api.example.com'
  config.access_token = ENV.fetch('ACCESS_TOKEN')
end
```

The final configuration object is frozen after `process_config` runs.

## Development

After checking out the repo, run:

```sh
bin/setup
bundle exec rake spec
```

You can also run `bin/console` for an interactive prompt.

To install this gem locally:

```sh
bundle exec rake install
```

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
