# frozen_string_literal: true

module Bluesky
  module Actors
    def self.account(actor)
      Social::Structs::Account.new(
        avatar: actor["avatar"], handle: actor["handle"].to_s, name: actor["displayName"].to_s.strip,
      )
    end

    def self.accounts(body) = body["actors"].to_a.map { account(it) }
  end
end
