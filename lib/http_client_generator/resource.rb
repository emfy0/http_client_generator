# frozen_string_literal: true

require 'http'

module HttpClientGenerator
  class Resource # :nodoc:
    attr_reader :verb, :content_type, :name, :req_plugs, :resp_head_plugs, :resp_plugs, :base, :timeout, :stream

    # rubocop:disable Metrics/ParameterLists
    def initialize(verb:, content_type:, timeout:, name:, base:, req_plugs:, resp_head_plugs:, resp_plugs:,
                   stream: false)
      @verb = verb
      @base = base
      @content_type = content_type
      @timeout = timeout
      @name = name
      @stream = stream
      @req_plugs = select_plugs(req_plugs)
      @resp_head_plugs = select_plugs(resp_head_plugs)
      @resp_plugs = select_plugs(resp_plugs)
      validate_streaming_plugs!
    end
    # rubocop:enable Metrics/ParameterLists

    def perform_request(url_helper, url_options, body, rest_args, timeout_override)
      request = prepare_request(url_helper, url_options, body, rest_args, timeout_override)

      response = perform_http_request(request)
      request.response_status = response.status.code
      request = process_response_head(request)

      return response.body if stream

      request.response_body = response.to_s

      process_response(request)
    rescue HTTP::Error => e
      request.raise_error(e)
    end

    private

    def prepare_request(url_helper, url_options, body, rest_args, timeout_override)
      url = url_helper.public_send(:"#{name}", url_options)
      request = build_request(url, body, rest_args, timeout_override)

      req_plugs.reduce(request) { |req, plug| plug.call(req) }
    end

    def build_request(url, body, rest_args, timeout_override)
      Request.new(
        name: name,
        verb: verb,
        url: url,
        content_type: content_type,
        timeout: timeout_override.nil? ? timeout : TimeoutNormalizer.call(timeout_override),
        body: body,
        rest_args: rest_args,
        base: base
      )
    end

    def perform_http_request(request)
      http_client = HTTP[request.current_headers]
      http_client = http_client.timeout(request.timeout) unless request.timeout.nil?

      http_client.public_send(*request_attributes(request))
    end

    def request_attributes(request)
      attributes = [request.verb, request.url]
      attributes << { body: request.raw_body } if request.body
      attributes
    end

    def process_response(request)
      resp_plugs.reduce(request) { |req, plug| plug.call(req) }

      request.response_body
    end

    def process_response_head(request)
      resp_head_plugs.reduce(request) { |req, plug| plug.call(req) }
    end

    def validate_streaming_plugs!
      return unless stream && resp_plugs.any?

      raise ArgumentError, "Streaming resource #{name.inspect} cannot use response body plugs"
    end

    def select_plugs(plug_entries)
      plug_entries.filter_map do |entry|
        only = entry[:only]
        except = entry[:except]
        plug = entry[:plug]

        next if only.any? && !only.include?(name)
        next if except.include?(name)

        plug
      end
    end
  end
end
