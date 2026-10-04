# frozen_string_literal: true

module Activity
  module Operations
    class SnoozeAttention < Blog::Operation
      WEEK = 7 * 24 * 60 * 60

      include Deps[attention_repo: "repos.attention_repo"]

      def call(kind, record_id = nil, now: Time.now)
        step find(kind, record_id)

        attention_repo.snooze(kind:, record_id:, ends_at: now + WEEK, now:)
      end

      private

      def find(kind, record_id)
        attention_repo.listed?(kind:, record_id:) ? Success(kind) : Failure(:not_found)
      end
    end
  end
end
