# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Place < Action
        include Deps[place_task: "tasks.operations.place_task"]

        def handle(request, response)
          case place_task.call(record_id(request), after_id(request))
            in Success(_) then response.status = :no_content
            in Failure(:not_found) then halt :not_found
            in Failure(:not_placed | :apart | :after_not_found) then halt :unprocessable_content
          end
        end

        private

        def after_id(request)
          after = request.params[:after]
          return if after.to_s.empty?

          Blog::Types::IdParam[after] || halt(:unprocessable_content)
        end
      end
    end
  end
end
