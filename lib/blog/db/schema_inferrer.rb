# frozen_string_literal: true

require "rom/sql"

module Blog
  module DB
    class SchemaInferrer < ROM::SQL::Schema::Inferrer
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
