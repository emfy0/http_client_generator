# frozen_string_literal: true

require 'securerandom'

module HttpClientGenerator
  class Plugs
    class SetRequestId
      Plugs.register :set_request_id, self

      def initialize(header_name)
        @header_name = header_name
      end

      def call(req)
        request_id = req.rest_args[:request_id] || SecureRandom.uuid

        req.headers[@header_name] = request_id
        req.extra[:request_id] = request_id

        req
      end
    end
  end
end
