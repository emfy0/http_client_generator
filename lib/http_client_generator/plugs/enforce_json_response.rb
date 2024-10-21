# frozen_string_literal: true

module HttpClientGenerator
  class Plugs
    class EnforceJsonResponse
      Plugs.register :enforce_json_response, self

      def call(request)
        request.response_body = JSON.parse(request.response_body, symbolize_names: true)
        request
      rescue JSON::ParserError => e
        request.raise_error(e)
      end
    end
  end
end
