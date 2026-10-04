# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module WorkEntries
      module_function

      def missing(id) = "no work entry has the ID #{id}"
    end
  end
end
