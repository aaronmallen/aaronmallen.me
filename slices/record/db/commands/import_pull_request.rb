# frozen_string_literal: true

module Record
  module DB
    module Commands
      class ImportPullRequest < ROM::SQL::Postgres::Commands::Upsert
        RESTATED = %i[body closed_at merged_at ready_at title updated_at url].freeze

        relation :pull_requests
        register_as :import
        result :one
        use :timestamps
        timestamps :created_at, :updated_at

        conflict_target %i[repo number]
        update_statement(RESTATED.to_h { [it, Sequel[:excluded][it]] })
      end
    end
  end
end
