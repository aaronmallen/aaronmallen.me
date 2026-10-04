# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module Projects
      ID = Schema::ID

      module_function

      def missing(id) = "no project has the ID #{id}"
    end
  end
end
