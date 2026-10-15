# frozen_string_literal: true

require "rom/sql"

module Blog
  module DB
    class SchemaInferrer < ROM::SQL::Schema::Inferrer
      UNSELECTED = %i[search_vector].freeze

      def call(...)
        inferred = super

        { **inferred, attributes: inferred[:attributes].reject { UNSELECTED.include?(it.name) } }
      end
    end
  end
end
