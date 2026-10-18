# frozen_string_literal: true

module API
  module Operations
    class WakeInboxRow < Blog::Operation
      include Deps[
        wake_message: "mail.operations.wake_message",
        wake_task: "tasks.operations.wake_task",
        wake_webmention: "social.operations.wake_webmention",
      ]

      def call(kind, id, now: Time.now)
        step found(Structs::InboxRow::KINDS.key(kind))
        record = step __send__(:"wake_#{kind}").call(id, now:)

        Structs::InboxRow.new(kind: kind.to_sym, at: now, record:)
      end
    end
  end
end
