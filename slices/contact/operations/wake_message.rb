# frozen_string_literal: true

module Contact
  module Operations
    class WakeMessage < Operation
      include Deps[message_repo: "repos.message_repo"]

      def call(id, now: Time.now)
        message = step found(message_repo.by_id(id))
        step snoozed(message, now)

        message_repo.snooze(id, now)
      end
    end
  end
end
