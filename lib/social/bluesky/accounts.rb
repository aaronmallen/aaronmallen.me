# frozen_string_literal: true

module Social
  module Bluesky
    class Accounts
      PROVIDER = Blog::Types::ServiceProvider["bluesky"]

      def initialize(connections, &sign_in)
        @authors = {}
        @connections = connections
        @lock = Mutex.new
        @sessions = {}
        @sign_in = sign_in
      end

      def any? = !first_credentials.nil?

      def sessions(author = nil, credentials = nil)
        known = author && @lock.synchronize { @authors[author] }
        return known if known

        found = credentials || first_credentials or raise Client::Error, "Bluesky has no connected account"
        @lock.synchronize { @sessions[found] ||= Sessions.new { @sign_in.call(found) } }
      end

      def wrote(author, sessions) = @lock.synchronize { @authors[author] = sessions }

      private

      def first_credentials = @connections.for(PROVIDER).first&.credentials
    end
  end
end
