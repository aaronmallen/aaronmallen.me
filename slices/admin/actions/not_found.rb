# frozen_string_literal: true

module Admin
  module Actions
    class NotFound < Action
      def handle(_request, response)
        not_found(response)
      end
    end
  end
end
