# frozen_string_literal: true

module Bluesky
  class Accounts
    PROVIDER = Blog::Types::ServiceProvider["bluesky"]

    def initialize(&sign_in)
      @lock = Mutex.new
      @sessions = {}
      @sign_in = sign_in
    end

    def any? = !first_credentials.nil?

    def sessions(credentials)
      raise Error, "Bluesky has no account to post as" unless credentials

      @lock.synchronize { @sessions[credentials] ||= Sessions.new { @sign_in.call(credentials) } }
    end

    private

    def first_credentials = services["repos.connection_queries"].for(PROVIDER).first&.credentials

    def services = Hanami.app.slices[:services]
  end
end
