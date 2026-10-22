# frozen_string_literal: true

module Contacts
  module Repos
    class PersonMutations < Blog::DB::Repo
      root :people

      stamped_commands :create, :update
      commands delete: :by_pk

      def store_google(google_connection_id, found, now: Time.now)
        transaction do
          link_local(google_connection_id, found[:people]) if found[:first]
          people.store(google_connection_id, found[:people], now:)
          stale(google_connection_id, found).delete
          keep_sync_token(google_connection_id, found[:sync_token], now)
          found[:people].size
        end
      end

      private

      def keep_sync_token(google_connection_id, sync_token, now)
        return contact_syncs.where(google_connection_id:).delete unless sync_token

        upsert = contact_syncs.dataset.insert_conflict(
          target: :google_connection_id, update: { sync_token:, updated_at: now },
        )
        upsert.insert(google_connection_id:, sync_token:, created_at: now, updated_at: now)
      end

      def link_local(google_connection_id, rows)
        held = people.where(google_connection_id:).pluck(:google_id)
        local = people.where(google_connection_id: nil).to_a

        Helpers::LocalMatch.pairs(local, rows.reject { held.include?(it[:google_id]) }).each do |person, row|
          people.by_pk(person.id).update(google_connection_id:, google_id: row[:google_id])
        end
      end

      def stale(google_connection_id, found)
        linked = people.where(google_connection_id:)
        return linked.where(google_id: found[:gone]) unless found[:full]

        linked.exclude(google_id: found[:people].map { it[:google_id] })
      end
    end
  end
end
