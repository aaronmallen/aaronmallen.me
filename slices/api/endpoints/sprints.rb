# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module Sprints
      DAY = { type: "string", description: "a day after today, as YYYY-MM-DD" }.freeze
      ID = { type: "integer" }.freeze
      UNSAVED = "could not save the change"

      module_function

      def missing(id) = "no sprint has the ID #{id}"
    end
  end
end
