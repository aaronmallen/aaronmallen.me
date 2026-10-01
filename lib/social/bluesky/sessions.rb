# frozen_string_literal: true

module Social
  module Bluesky
    class Sessions
      def initialize(&sign_in)
        @current = nil
        @lock = Mutex.new
        @sign_in = sign_in
      end

      def use
        session = current
        yield session
      rescue Client::Expired
        yield renew(session)
      end

      private

      def current = @lock.synchronize { @current ||= @sign_in.call }

      def renew(stale)
        @lock.synchronize do
          @current = @sign_in.call if @current.nil? || @current.equal?(stale)
          @current
        end
      end
    end
  end
end
