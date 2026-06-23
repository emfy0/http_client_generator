# frozen_string_literal: true

module HttpClientGenerator
  class Plugs
    class CamelizeBody # :nodoc:
      Plugs.register :camelize_body, self

      def call(req)
        body =
          if req.json? && req.body.is_a?(Hash)
            KeyTransformer.deep_transform_keys(req.body) { |key| Inflector.camelize_lower(key).to_sym }
          else
            req.body
          end

        req.body = body

        req
      end
    end
  end
end
