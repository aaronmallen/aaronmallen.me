# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module Commits
      ID = Schema::ID

      module_function

      def missing(id) = "no commit has the ID #{id}"
    end
  end
end
