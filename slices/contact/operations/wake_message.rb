# frozen_string_literal: true

module Contact
  module Operations
    class WakeMessage < Blog::Operation
      include Deps[message_mutations: "repos.message_mutations", message_queries: "repos.message_queries"]

      def call(id, now: Time.now)
        message = step found(message_queries.by_id(id))
        step snoozed(message, now)

        message_mutations.snooze(id, now)
      end
    end
  end
end
