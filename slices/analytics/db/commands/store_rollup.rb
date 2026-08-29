# frozen_string_literal: true

module Analytics
  module DB
    module Commands
      class StoreRollup < ROM::SQL::Postgres::Commands::Upsert
        RESTATED = %i[views visitors read_seconds updated_at].freeze

        relation :analytics_rollups
        register_as :store
        result :one
        use :timestamps
        timestamps :created_at, :updated_at

        conflict_target :day
        update_statement(RESTATED.to_h { [it, Sequel[:excluded][it]] })
      end
    end
  end
end
