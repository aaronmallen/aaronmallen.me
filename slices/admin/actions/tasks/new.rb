# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class New < Action
        include Redirect

        def handle(request, response)
          empty = Dry::Core::Constants::EMPTY_HASH

          response.render(view, errors: empty, origin: task_origin(request), values: empty)
        end
      end
    end
  end
end
