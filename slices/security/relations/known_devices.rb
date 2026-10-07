# frozen_string_literal: true

module Security
  module Relations
    class KnownDevices < Blog::DB::Relation
      KEY = %i[api_token_id oauth_client_id browser os city country].freeze

      schema :known_devices, infer: true

      def know(row, at:) = upsert(row.merge(created_at: at), target: KEY)
    end
  end
end
