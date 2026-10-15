# frozen_string_literal: true

module Shares
  module Relations
    class ShortLinkChecks < Blog::DB::Relation
      schema :short_link_checks, infer: true

      def record(short_link_id:, url:, reason:, at:)
        failures = reason ? 1 : 0
        first_failed_at = at if reason
        update = excluded(%i[reason checked_at]).merge(
          failures: reason ? Sequel[:short_link_checks][:failures] + 1 : 0,
          first_failed_at: reason ? Sequel.function(:coalesce, Sequel[:short_link_checks][:first_failed_at], at) : nil,
        )

        row = { short_link_id:, url:, reason:, failures:, first_failed_at:, checked_at: at }
        upsert(row, target: :short_link_id, update:)
      end

      def stale(destinations) = exclude(%i[short_link_id url] => destinations)
    end
  end
end
