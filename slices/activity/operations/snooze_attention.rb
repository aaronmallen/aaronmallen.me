# frozen_string_literal: true

module Activity
  module Operations
    class SnoozeAttention < Blog::Operation
      WEEK = 7 * 24 * 60 * 60

      include Deps[attention_queries: "repos.attention_queries", attention_mutations: "repos.attention_mutations"]

      def call(kind, record_id = nil, now: Time.now)
        step find(kind, record_id)

        attention_mutations.snooze(kind:, record_id:, ends_at: now + WEEK, now:)
      end

      private

      def find(kind, record_id)
        found(attention_queries.listed?(kind:, record_id:) && kind)
      end
    end
  end
end
