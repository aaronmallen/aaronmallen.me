# frozen_string_literal: true

module Activity
  module Queries
    class StalledList
      include Deps["settings", attention_repo: "repos.attention_repo"]

      def call(now: Time.now, on: Blog::TimeZone.today(now))
        limits = settings.attention

        attention_repo.stalled(on:, now:, **limits).map { Structs::StalledRow.from(it, on:, limits:) }.sort_by(&:rank)
      end
    end
  end
end
