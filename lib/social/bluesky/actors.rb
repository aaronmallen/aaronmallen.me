# frozen_string_literal: true

module Social
  module Bluesky
    module Actors
      def self.account(actor)
        Account.new(avatar: actor["avatar"], handle: actor["handle"].to_s, name: actor["displayName"].to_s.strip)
      end

      def self.accounts(body) = body["actors"].to_a.map { account(it) }
    end
  end
end
