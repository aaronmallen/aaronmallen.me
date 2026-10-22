# frozen_string_literal: true

module Contacts
  module Repos
    class PersonQueries < Blog::DB::Repo
      SHOWS = { "starred" => :starred, "mentionable" => :mentionable }.freeze

      def all = people.in_name_order.to_a

      def by_email(email) = people.with_email(email).first

      def by_id(id) = people.by_pk(id).one

      def by_keys(keys) = people.where(key: keys).to_a

      def count = people.count

      def emailed = people.emailed.in_name_order.to_a

      def labels = people.label_names.map(:label)

      def last_synced_at = contact_syncs.dataset.max(:updated_at)

      def listed(query: nil, show: nil, label: nil)
        found = people
        found = found.public_send(SHOWS.fetch(show)) if SHOWS.key?(show)
        found = found.labeled(label) if label
        found = found.matching(query) if query
        found.in_file_order.to_a
      end

      def mentionable = people.mentionable.in_name_order.to_a

      def sync_tokens = contact_syncs.dataset.select_map(%i[google_connection_id sync_token]).to_h
    end
  end
end
