# frozen_string_literal: true

module API
  module Operations
    class SnoozeInboxRow < Blog::Operation
      Snooze = Data.define(:kind, :id, :snoozed_until)

      include Deps[
        snooze_messages: "contact.operations.snooze_messages",
        snooze_tasks: "tasks.operations.snooze_tasks",
        snooze_webmentions: "social.operations.snooze_webmentions",
      ]

      def call(kind, id, snoozed_until, now: Time.now)
        ends_at = step ahead(snoozed_until, now)
        step snooze(kind, id, ends_at)
        Snooze.new(kind:, id:, snoozed_until: ends_at)
      end

      private

      def ahead(text, now)
        at = Blog::TimeZone.parse_time(text)
        return Failure(:invalid) unless at

        at > now ? Success(at) : Failure(:past)
      end

      def operation(kind)
        { "message" => snooze_messages, "task" => snooze_tasks, "webmention" => snooze_webmentions }[kind]
      end

      def snooze(kind, id, ends_at)
        found = operation(kind)
        return Failure(:not_found) unless found

        found.call([id], ends_at).alt_map { :not_found }
      end
    end
  end
end
