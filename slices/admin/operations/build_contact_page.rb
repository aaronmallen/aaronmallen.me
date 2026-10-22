# frozen_string_literal: true

module Admin
  module Operations
    class BuildContactPage
      THREADS = 6

      include Deps[
        connection_queries: "services.repos.connection_queries",
        person_queries: "contacts.repos.person_queries",
        thread_queries: "mail.repos.thread_queries",
      ]

      def call(id)
        person = person_queries.by_id(id)
        return unless person

        { person:, threads: threads(person), connection: connection(person) }
      end

      private

      def connection(person) = person.google_connection_id&.then { connection_queries.by_id(it) }

      def threads(person) = thread_queries.latest_with(person.emails.map { it["value"] }, limit: THREADS)
    end
  end
end
