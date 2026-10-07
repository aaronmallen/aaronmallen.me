# frozen_string_literal: true

module Security
  module Relations
    class Sightings < Blog::DB::Relation
      KEY = %i[api_token_id oauth_client_id browser os city country].freeze

      schema :sightings, infer: true

      def newest_first = order(self[:last_seen_at].desc, self[:id].desc)

      def sight(row, at:)
        update = excluded(%i[last_address last_user_agent last_seen_at]).merge(calls: Sequel[:sightings][:calls] + 1)

        upsert(row.merge(first_seen_at: at, last_seen_at: at), target: KEY, update:)
      end
    end
  end
end
