# frozen_string_literal: true

require "blog/extensions"
require "rom/sql"
require "rom/sql/extensions/postgres"

module Blog
  module Extensions
    module ROM
      module SQL
        module Postgres
          module TypeBuilder
            module Extension
              TSVECTOR = "tsvector"

              def map_db_type(db_type) = db_type == TSVECTOR ? ::ROM::SQL::Types::String : super
            end
          end
        end
      end
    end
  end
end

Blog::Extensions.apply(
  ROM::SQL::Postgres::TypeBuilder,
  Blog::Extensions::ROM::SQL::Postgres::TypeBuilder::Extension,
  gem: "rom-sql",
  version: "3.7.0",
  reason: "rom-sql maps no type to tsvector, so it cannot infer the schema of a relation with a search column",
  upstream: nil,
)
