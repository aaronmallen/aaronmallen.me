# frozen_string_literal: true

module Social
  module DB
    module Commands
      class ClaimReceipt < ROM::SQL::Postgres::Commands::Upsert
        RESTATED = %i[received_at updated_at visitor_hash].freeze

        relation :webmention_receipts
        register_as :claim
        result :many
        use :timestamps
        timestamps :created_at, :received_at, :updated_at

        conflict_target %i[post_id source_url]
        update_statement(RESTATED.to_h { [it, Sequel[:excluded][it]] })
      end
    end
  end
end
