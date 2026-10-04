# frozen_string_literal: true

module Activity
  module Relations
    class AttentionSnoozes < Blog::DB::Relation
      KEY = %i[kind record_id].freeze

      schema :attention_snoozes, infer: true

      def snooze(kind:, record_id:, ends_at:, now:)
        update = excluded(%i[ends_at updated_at])

        upsert({ kind:, record_id:, ends_at:, created_at: now, updated_at: now }, target: KEY, update:)
      end
    end
  end
end
