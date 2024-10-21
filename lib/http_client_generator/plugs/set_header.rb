# frozen_string_literal: true

module HttpClientGenerator
  class Plugs
    class SetHeader
      Plugs.register :set_header, self

      def initialize(arg:, header:, func: nil)
        @arg = arg
        @header = header
        @func = func
      end

      def call(req)
        arg = req.rest_args[@arg]

        req.headers[@header] =
          case @func&.arity
          in 1
            @func.(arg)
          in 2
            @func.(req, arg)
          in nil
            arg
          end

        req
      end
    end
  end
end
