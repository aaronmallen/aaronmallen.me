# frozen_string_literal: true

module API
  module Serializers
    class Sprint < Serializer
      SCHEMA = Schema.object({ id: Schema::INTEGER, date: Schema::DAY, carried_in: Schema::INTEGER }).freeze

      schema_attributes

      def date(sprint) = day(sprint.sprint_date)
    end
  end
end
