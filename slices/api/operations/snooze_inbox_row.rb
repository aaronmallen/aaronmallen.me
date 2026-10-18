# frozen_string_literal: true

module API
  module Operations
    class SnoozeInboxRow < Blog::Operation
      Snooze = Data.define(:kind, :id, :snoozed_until)

      include Deps[
        snooze_messages: "mail.operations.snooze_messages",
        snooze_tasks: "tasks.operations.snooze_tasks",
        snooze_webmentions: "social.operations.snooze_webmentions",
      ]

      def call(kind, id, snoozed_until, now: Time.now)
        ends_at = step upcoming_time(snoozed_until, now)
        step snooze(kind, id, ends_at)
        Snooze.new(kind:, id:, snoozed_until: ends_at)
      end

      private

      def snooze(kind, id, ends_at)
        kinds = Structs::InboxRow::KINDS.key(kind)
        return Failure(:not_found) unless kinds

        __send__(:"snooze_#{kinds}").call([id], ends_at).alt_map { :not_found }
      end
    end
  end
end
