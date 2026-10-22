# frozen_string_literal: true

module Security
  module Relations
    class Sightings < Blog::DB::Relation
      KEY = %i[api_token_id oauth_client_id browser os product].freeze

      schema :sightings, infer: true

      def last_seen_before(time) = where { last_seen_at < time }

      def newest_first = order(self[:last_seen_at].desc, self[:id].desc)

      def sight(row, at:)
        device = row.except(:last_address, :last_user_agent, :product).merge(created_at: at)
        known = dataset.db[:known_devices].insert_conflict(target: KnownDevices::KEY).with_sql(:insert_sql, device)
        latest = excluded(%i[city country country_name last_address last_user_agent last_seen_at])
        update = latest.merge(calls: Sequel[:sightings][:calls] + 1)

        sightings = dataset.with(:known, known).insert_conflict(target: KEY, update:)

        sightings.insert(row.merge(first_seen_at: at, last_seen_at: at))
      end
    end
  end
end
