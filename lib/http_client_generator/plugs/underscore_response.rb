# frozen_string_literal: true

module HttpClientGenerator
  class Plugs
    class UnderscoreResponse
      Plugs.register :underscore_response, self

      def call(req)
        return req unless req.response_body.is_a?(Hash)

        req.response_body = req.response_body.deep_transform_keys { |k| k.to_s.underscore.to_sym }

        req
      end
    end
  end
end
