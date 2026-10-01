# frozen_string_literal: true

module API
  module Serializers
    class Sprint < Serializer
      SCHEMA = Schema.object({ id: Schema::INTEGER, date: Schema::DAY, carried_in: Schema::INTEGER }).freeze

      attributes :id, :date, :carried_in

      def date(sprint) = day(sprint.sprint_date)
    end
  end
end
