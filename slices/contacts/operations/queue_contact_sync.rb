# frozen_string_literal: true

module Contacts
  module Operations
    class QueueContactSync < Blog::Operation
      def call = step(queued { Jobs::SyncContacts.perform_async })
    end
  end
end
