# frozen_string_literal: true

module HttpClientGenerator
  class Plugs
    class EncodeJsonResponse
      Plugs.register :encode_json_response, self

      def call(request)
        request.response_body = JSON.parse(request.response_body, symbolize_names: true)
        request
      rescue JSON::ParserError
        request
      end
    end
  end
end
