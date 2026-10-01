# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Place < Action
        NO_CONTENT = 204

        include Deps[place_task: "tasks.operations.place_task"]

        def handle(request, response)
          case place_task.call(record_id(request), after_id(request))
          in Success(_) then response.status = NO_CONTENT
          in Failure(:not_found) then halt 404
          in Failure(:not_placed) then halt 422
          else halt 500
          end
        end

        private

        def after_id(request)
          after = request.params[:after]
          return if after.to_s.empty?

          Blog::Types::IdParam[after] || halt(422)
        end
      end
    end
  end
end
