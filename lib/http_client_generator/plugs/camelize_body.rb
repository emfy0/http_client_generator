# frozen_string_literal: true

module HttpClientGenerator
  class Plugs
    class CamelizeBody
      Plugs.register :camelize_body, self

      def call(req)
        body =
          if req.json? && req.body.is_a?(Hash)
            req.body.deep_transform_keys { |key| key.to_s.camelize(:lower).to_sym }
          else
            req.body
          end

        req.body = body

        req
      end
    end
  end
end
