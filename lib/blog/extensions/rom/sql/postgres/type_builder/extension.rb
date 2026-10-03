# frozen_string_literal: true

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

ROM::SQL::Postgres::TypeBuilder.prepend(Blog::Extensions::ROM::SQL::Postgres::TypeBuilder::Extension)
