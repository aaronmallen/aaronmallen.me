# frozen_string_literal: true

module Activity
  module Repos
    class AttentionRepo < Blog::DB::Repo
      def listed?(kind:, record_id:) = attention.where(kind:, record_id:).exist?

      def snooze(kind:, record_id:, ends_at:, now:)
        attention_snoozes.snooze(kind:, record_id:, ends_at:, now:)
        attention_snoozes.where(kind:, record_id:).one
      end

      def stalled(on:, now:, **limits) = attention.stalled(on:, now:, **limits).to_a
    end
  end
end
