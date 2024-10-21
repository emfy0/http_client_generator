# frozen_string_literal: true

module HttpClientGenerator
  class Plugs
    class SetBearerToken
      Plugs.register :set_bearer_token, self

      def initialize(from_arg:)
        @from_arg = from_arg
      end

      def call(req)
        token = req.rest_args[@from_arg]

        req.headers[:authorization] = "Bearer #{token}"

        req
      end
    end
  end
end
