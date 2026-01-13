# frozen_string_literal: true

module HttpClientGenerator
  class Request
    CONTENT_TYPES = %i[json text].freeze

    DEFAULT_HEADERS_BY_CONTENT_TYPE = {
      json: { accept: 'application/json', content_type: 'application/json' },
      text: { content_type: 'text/plain' },
    }.freeze

    CONTENT_TYPES.each do |type|
      define_method "#{type}?" do
        type == content_type
      end
    end

    attr_accessor :verb, :name, :content_type, :url, :headers, :body, :rest_args, :response_body, :base, :extra

    def initialize(base:, name:, verb:, content_type:, url:, body:, rest_args:)
      @base = base
      @name = name
      @verb = verb
      @content_type = content_type
      @url = url
      @rest_args = rest_args
      @body = body
      @headers = {}
      @extra = {}
    end

    def current_headers
      default_headers.merge(headers)
    end

    def raw_body
      if json?
        body && body.to_json
      else
        body
      end
    end

    def raise_error(e)
      Sentry.capture_exception(e, extra: { request_id: extra[:request_id] }) if Object.const_defined?(:Sentry)
      raise base::RequestError, e.message, e.backtrace, cause: nil
    end

    def raise_message(message)
      Sentry.capture_message(message, extra: { request_id: extra[:request_id] }) if Object.const_defined?(:Sentry)
      raise base::RequestError, message
    end

    private

    def default_headers
      DEFAULT_HEADERS_BY_CONTENT_TYPE[content_type]
    end
  end
end
