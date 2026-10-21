# frozen_string_literal: true

module Shares
  module Helpers
    module Code
      ATTEMPTS = 5
      KEY = "short_codes_code_key"
      TAKEN = "taken"
      CONSTRAINTS = { KEY => [:code, TAKEN] }.freeze

      def self.retrying(repo, attempts = ATTEMPTS, &)
        yield
      rescue ROM::SQL::UniqueConstraintError => e
        raise unless repo.violated_constraint(e) == KEY && attempts > 1

        retrying(repo, attempts - 1, &)
      end
    end
  end
end
