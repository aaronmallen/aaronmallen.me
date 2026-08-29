# frozen_string_literal: true

module Record
  module DB
    module Commands
      class ImportCommit < ROM::SQL::Postgres::Commands::Upsert
        RESTATED = %i[additions deletions message updated_at].freeze

        relation :commits
        register_as :import
        result :one
        use :timestamps
        timestamps :created_at, :updated_at

        conflict_target :sha
        update_statement(RESTATED.to_h { [it, Sequel[:excluded][it]] })
      end
    end
  end
end
