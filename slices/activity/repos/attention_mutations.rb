# frozen_string_literal: true

module Activity
  module Repos
    class AttentionMutations < Blog::DB::Repo
      def snooze(kind:, record_id:, ends_at:, now:)
        attention_snoozes.snooze(kind:, record_id:, ends_at:, now:)
        attention_snoozes.where(kind:, record_id:).one
      end
    end
  end
end
