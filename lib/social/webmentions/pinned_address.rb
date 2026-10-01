# frozen_string_literal: true

require "faraday"

module Social
  module Webmentions
    class PinnedAddress < Faraday::Adapter::NetHttp
      module Bounded
        attr_accessor :deadline

        private

        def on_connect
          @socket = BoundedBuffer.new(@socket.io, deadline:, read_timeout:, write_timeout:, continue_timeout:,
                                                  debug_output: @debug_output)
        end

        def ssl_socket_connect(socket, timeout) = super(socket, [timeout, deadline.left].min)
      end

      def build_connection(env)
        context = env[:request][:context].to_h

        super.tap do |http|
          http.ipaddr = context[:address]
          bound(http, context[:deadline])
        end
      end

      private

      def bound(http, deadline)
        http.open_timeout = [http.open_timeout, deadline.left].min
        http.extend(Bounded).deadline = deadline
      end
    end
  end
end
