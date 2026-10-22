# frozen_string_literal: true

module Contacts
  module Jobs
    class SyncContacts < Blog::ScheduledJob
      SYNC = Blog::Types::SyncName["contacts"]

      include Record::SyncBookkeeping
      include Deps["operations.sync_contacts"]

      def perform = record_locked_sync(SYNC) { sync_contacts.call }
    end
  end
end
