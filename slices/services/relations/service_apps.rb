# frozen_string_literal: true

module Services
  module Relations
    class ServiceApps < Blog::DB::Relation
      COLUMNS = %i[redirect_uri scopes credentials updated_at].freeze

      schema :service_apps, infer: true

      def store(row, at)
        row = row.merge(scopes: Sequel.pg_array(row[:scopes], :text), created_at: at, updated_at: at)

        dataset.insert_conflict(target: %i[provider host], update: excluded(COLUMNS)).insert(row)
      end
    end
  end
end
