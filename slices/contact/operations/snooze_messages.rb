# frozen_string_literal: true

module Contact
  module Operations
    class SnoozeMessages < Operation
      include Deps[message_repo: "repos.message_repo"]

      def call(ids, ends_at)
        each_record(ids) { found(message_repo.snooze(it, ends_at)) }
      end
    end
  end
end
