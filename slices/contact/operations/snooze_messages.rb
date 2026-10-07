# frozen_string_literal: true

module Contact
  module Operations
    class SnoozeMessages < Operation
      include Deps[message_mutations: "repos.message_mutations"]

      def call(ids, ends_at)
        each_record(ids) { found(message_mutations.snooze(it, ends_at)) }
      end
    end
  end
end
