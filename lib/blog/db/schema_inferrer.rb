# frozen_string_literal: true

require "blog/extensions"
require "rom/sql"

module Blog
  module DB
    class SchemaInferrer < ROM::SQL::Schema::Inferrer
      Extensions.pin(
        self,
        gem: "rom-sql",
        version: "3.7.0",
        reason: "this subclass drops tsvector columns and the indexes left with a nil attribute over them, " \
                "through rom-sql's private filter_columns, indexes_from_database and attributes_index",
        upstream: nil,
      )

      class AttributesInferrer < ROM::SQL::Schema::AttributesInferrer
        UNREAD = "tsvector"

        def filter_columns(...) = super.reject { |_, definition| definition[:db_type] == UNREAD }
      end

      attributes_inferrer lambda { |schema, gateway, options|
        type_builder = ROM::SQL::Schema::TypeBuilder[gateway.database_type]
        AttributesInferrer.new(type_builder:, **options).call(schema, gateway)
      }

      def indexes_from_database(...) = super.reject { it.attributes.include?(nil) }

      private

      def attributes_index(attributes) = attributes.to_h { [it.name, it.unwrap] }
    end
  end
end
