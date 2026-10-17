# frozen_string_literal: true

module Shares
  module Operations
    class QueueTitleFetch
      include Deps[honeybadger: "honeybadger.agent", short_link_mutations: "repos.short_link_mutations"]

      def call(id)
        Jobs::FetchShortLinkTitle.perform_async(id)
      rescue RedisClient::Error => e
        honeybadger.notify(e)
        short_link_mutations.hold_title_fetch(id)
      end
    end
  end
end
