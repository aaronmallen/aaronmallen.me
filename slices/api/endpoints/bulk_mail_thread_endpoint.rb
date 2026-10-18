# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class BulkMailThreadEndpoint < BulkEndpoint
      CONTRACTS = [::Mail::Contracts::BulkContract].freeze
      COMPLAINTS = { tag: Helpers::Tags::COMPLAINTS }.freeze
      KEY = :mail_threads
      NOUN = "mail thread"
      REPLY = Helpers::Schema.object({ mail_threads: Helpers::Schema.list(Serializers::MailThread.reference) }).freeze
      SCHEMA = MailThreads::BULK

      include Deps[
        act_on: "mail.operations.act_on_messages",
        message_queries: "mail.repos.message_queries",
      ]

      private

      def answered(threads) = serialized(Serializers::MailThread, message_queries.by_ids_in_order(threads.map(&:id)))
    end
  end
end
