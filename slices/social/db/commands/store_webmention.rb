# frozen_string_literal: true

module Social
  module DB
    module Commands
      class StoreWebmention < ROM::SQL::Postgres::Commands::Upsert
        relation :webmentions
        register_as :store
        result :one
        use :timestamps
        timestamps :created_at, :updated_at

        conflict_target %i[post_id source_url]
      end
    end
  end
end
