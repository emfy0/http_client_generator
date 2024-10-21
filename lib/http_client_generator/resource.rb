# frozen_string_literal: true

require 'http'

module HttpClientGenerator
  class Resource
    attr_reader :verb, :content_type, :name, :req_plugs, :resp_plugs, :base

    def initialize(verb:, content_type:, name:, base:, req_plugs:, resp_plugs:)
      @verb = verb
      @base = base
      @content_type = content_type
      @name = name
      @req_plugs = req_plugs
      @resp_plugs = resp_plugs
    end

    def perform_request(url_helper, url_options, body, rest_args)
      request = prepare_request(url_helper, url_options, body, rest_args)

      request_attributes = [request.verb, request.url]

      if request.body
        request.body = request.body.to_json if request.json?
        request_attributes << { body: request.body }
      end

      request.response_body = HTTP[request.current_headers].public_send(*request_attributes).to_s

      process_response(request)
    rescue HTTP::Error => e
      request.raise_error(e)
    end

    private

    def prepare_request(url_helper, url_options, body, rest_args)
      url = url_helper.public_send(:"#{name}", url_options)

      request = Request.new(
        name: name, verb: verb, url: url, content_type: content_type, body: body, rest_args: rest_args, base: base
      )

      req_plugs.reduce(request) { |req, plug| plug.call(req) }
    end

    def process_response(request)
      resp_plugs.reduce(request) { |req, plug| plug.call(req) }

      request.response_body
    end
  end
end
