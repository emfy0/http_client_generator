# frozen_string_literal: true

module HttpClientGenerator
  class Plugs
    class ValidateResponse
      Plugs.register :validate_response, self

      def initialize(schema_helper:, show_body_in_error: false)
        @schema_helper = schema_helper
        @show_body_in_error = show_body_in_error
      end

      def call(req)
        schema_name = :"#{req.verb}_#{req.name}"

        return req unless @schema_helper.respond_to?(schema_name)

        req.response_body =
          @schema_helper
            .public_send(schema_name, req.response_body)
            .value_or do |e|
              message =
                if @show_body_in_error
                  "Unexpected #{e.inspect} in #{req.response_body}"
                else
                  "Unexpected #{e.inspect}"
                end

              req.raise_message(message)
            end

        req
      end
    end
  end
end
