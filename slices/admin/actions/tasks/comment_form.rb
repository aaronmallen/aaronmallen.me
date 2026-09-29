# auto_register: false
# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      module CommentForm
        include Dry::Monads[:result]

        private

        def comment_params(request) = Blog::Types::Fields[request.params[:comment]]

        def refuse_comment(request, response, commenting)
          case build_task_page.call(record_id(request), commenting:)
          in Success(page)
            response.status = 422
            response.render(task_view, **page, **return_to(request))
          in Failure(:not_found) then halt 404
          else halt 500
          end
        end

        def written(request, response, key)
          toast(response, key)
          response.redirect_to(tasks_path(request))
        end
      end
    end
  end
end
