# frozen_string_literal: true

module API
  module Operations
    class WakeInboxRow < Operation
      WAKES = { "message" => :wake_message, "task" => :wake_task, "webmention" => :wake_webmention }.freeze

      include Deps[
        wake_message: "contact.operations.wake_message",
        wake_task: "tasks.operations.wake_task",
        wake_webmention: "social.operations.wake_webmention",
      ]

      def call(kind, id, now: Time.now)
        wake = step found(WAKES[kind])
        record = step __send__(wake).call(id, now:)

        Queries::Inbox::Row.new(kind: kind.to_sym, at: now, record:)
      end
    end
  end
end
