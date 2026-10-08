# frozen_string_literal: true

module API
  module Serializers
    class Sprint < Serializer
      SCHEMA = Helpers::Schema.object(
        { id: Helpers::Schema::INTEGER, date: Helpers::Schema::DAY, carried_in: Helpers::Schema::INTEGER },
      ).freeze

      schema_attributes

      def date(sprint) = day(sprint.sprint_date)
    end
  end
end
