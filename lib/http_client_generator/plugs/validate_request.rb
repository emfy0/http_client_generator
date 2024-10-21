# frozen_string_literal: true

module HttpClientGenerator
  class Plugs
    class ValidateRequest
      Plugs.register :validate_request, self

      def initialize(schema_helper:)
        @schema_helper = schema_helper
      end

      def call(req)
        schema_name = :"#{req.verb}_#{req.name}"

        return req unless @schema_helper.respond_to?(schema_name)

        req.response_body = @schema_helper.public_send(schema_name, req.body)
          .value_or { |e| req.raise_message("Unexpected #{e.inspect} in #{req.body}") }

        req
      end
    end
  end
end
