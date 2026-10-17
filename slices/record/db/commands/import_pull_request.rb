# frozen_string_literal: true

module Record
  module DB
    module Commands
      class ImportPullRequest < ROM::SQL::Postgres::Commands::Upsert
        COMPARED = %i[body closed_at merged_at opened_at ready_at title url].freeze
        CHANGED = %i[pull_requests excluded].map { |table| COMPARED.map { Sequel[table][it] } }.freeze
        RESTATED = [*COMPARED, :updated_at].freeze

        relation :pull_requests
        register_as :import
        result :many
        use :timestamps
        timestamps :created_at, :updated_at

        conflict_target %i[repo number]
        update_statement(RESTATED.to_h { [it, Sequel[:excluded][it]] })
        update_where(Sequel.is_distinct_from(*CHANGED))

        def execute(tuples) = returning_dataset.insert_conflict(upsert_options).multi_insert(tuples.map { input[it] })
      end
    end
  end
end
