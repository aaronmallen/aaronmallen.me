# frozen_string_literal: true

module Activity
  module Repos
    class AttentionQueries < DB::Repo
      include Deps["settings"]

      def listed?(kind:, record_id:) = attention.where(kind:, record_id:).exist?

      def stalled(now: Time.now, on: Blog::TimeZone.today(now))
        limits = settings.attention

        attention.stalled(on:, now:, **limits).to_a.map { Structs::StalledRow.from(it, on:, limits:) }.sort_by(&:rank)
      end
    end
  end
end
