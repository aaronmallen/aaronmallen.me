# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class New < Action
        def handle(_request, response)
          response.render(
            view, errors: Dry::Core::Constants::EMPTY_HASH, values: Dry::Core::Constants::EMPTY_HASH,
          )
        end
      end
    end
  end
end
