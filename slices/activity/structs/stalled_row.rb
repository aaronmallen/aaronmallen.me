# frozen_string_literal: true

module Activity
  module Structs
    class StalledRow < Data.define(:kind, :record_id, :title, :days, :limit)
      LIMITS = {
        Blog::Types::AttentionKind["carried"] => :carried_count,
        Blog::Types::AttentionKind["draft"] => :draft_days,
        Blog::Types::AttentionKind["journal"] => :journal_days,
        Blog::Types::AttentionKind["new_device"] => :new_device_days,
        Blog::Types::AttentionKind["someday"] => :someday_days,
      }.freeze
      NEW_DEVICE = Blog::Types::AttentionKind["new_device"]

      def self.from(row, on:, limits:)
        new(
          kind: row.kind,
          record_id: row.record_id,
          title: row.title,
          days: row.carried_count || (on - row.touched_on).to_i,
          limit: limits.fetch(LIMITS.fetch(row.kind)),
        )
      end

      def overdue = kind == NEW_DEVICE ? Float::INFINITY : (days - limit).fdiv(limit)

      def rank = [-overdue, kind, record_id.to_i]
    end
  end
end
