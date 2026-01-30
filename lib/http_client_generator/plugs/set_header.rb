# frozen_string_literal: true

module HttpClientGenerator
  class Plugs
    class SetHeader
      Plugs.register :set_header, self

      def initialize(arg: nil, value: nil, header:, func: nil)
        @arg = arg
        @header = header
        @func = func
        @value = value
      end

      def call(req)
        return process_header_value(req) if @value

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

      private

      def process_header_value(req)
        req.headers[@header] =
          if @value.is_a?(Proc)
            @value.()
          else
            @value
          end

        req
      end
    end
  end
end
