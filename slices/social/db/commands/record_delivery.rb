# frozen_string_literal: true

module Social
  module DB
    module Commands
      class RecordDelivery < ROM::SQL::Postgres::Commands::Upsert
        relation :social_post_deliveries
        register_as :record
        result :one
        use :timestamps
        timestamps :created_at, :updated_at

        conflict_target %i[social_post_id connection_id]
      end
    end
  end
end
