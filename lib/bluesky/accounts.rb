# frozen_string_literal: true

module Bluesky
  class Accounts
    PROVIDER = Blog::Types::ServiceProvider["bluesky"]

    def initialize(&sign_in)
      @authors = {}
      @lock = Mutex.new
      @sessions = {}
      @sign_in = sign_in
    end

    def any? = !first_credentials.nil?

    def sessions(author = nil, credentials = nil)
      known = author && @lock.synchronize { @authors[author] }
      return known if known

      found = credentials || first_credentials or raise Error, "Bluesky has no connected account"
      @lock.synchronize { @sessions[found] ||= Sessions.new { @sign_in.call(found) } }
    end

    def wrote(author, sessions) = @lock.synchronize { @authors[author] = sessions }

    private

    def first_credentials = services["repos.connection_queries"].for(PROVIDER).first&.credentials

    def services = Hanami.app.slices[:services]
  end
end
