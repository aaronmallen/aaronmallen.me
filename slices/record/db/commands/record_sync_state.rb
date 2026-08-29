# frozen_string_literal: true

module Record
  module DB
    module Commands
      class RecordSyncState < ROM::SQL::Postgres::Commands::Upsert
        relation :sync_states
        register_as :record
        result :one
        use :timestamps
        timestamps :created_at, :updated_at

        conflict_target %i[kind sync repo]
      end
    end
  end
end
