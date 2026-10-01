# frozen_string_literal: true

module API
  module Serializers
    class Sprint < Serializer
      attributes :id, :date, :carried_in

      def date(sprint) = day(sprint.sprint_date)
    end
  end
end
