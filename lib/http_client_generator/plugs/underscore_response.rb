# frozen_string_literal: true

module HttpClientGenerator
  class Plugs
    class UnderscoreResponse # :nodoc:
      Plugs.register :underscore_response, self

      def call(req)
        return req unless req.response_body.is_a?(Hash)

        req.response_body =
          KeyTransformer.deep_transform_keys(req.response_body) { |key| Inflector.underscore(key).to_sym }

        req
      end
    end
  end
end
