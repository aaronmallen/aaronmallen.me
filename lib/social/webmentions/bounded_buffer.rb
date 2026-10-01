# frozen_string_literal: true

require "net/http"

module Social
  module Webmentions
    class BoundedBuffer < Net::BufferedIO
      def initialize(io, deadline:, **)
        super(io, **)
        @deadline = deadline
        @stall = read_timeout
      end

      private

      def rbuf_fill
        left = @deadline.left
        raise Net::ReadTimeout, io unless left.positive?

        @read_timeout = [@stall, left].min
        super
      end
    end
  end
end
