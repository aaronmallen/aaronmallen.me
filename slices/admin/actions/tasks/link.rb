# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Link < PageAction
        LINKED = "tasks_page.toasts.linked"

        include Deps[link_tasks: "tasks.operations.link_tasks"]

        def handle(request, response)
          id = record_id(request)
          params = Blog::Types::Fields[request.params[:link]]

          if request.params[:link_find]
            find(request, response, id, params)
          else
            link(request, response, id, params)
          end
        end

        private

        def find(request, response, id, params)
          response.redirect_to(
            routes.path(
              :admin_task,
              id:, **return_to(request).compact,
              link_kind: Blog::Types::Text[params[:kind]], link_q: Blog::Types::TrimmedText[request.params[:link_q]],
            ),
          )
        end

        def link(request, response, id, params)
          result = link_tasks.call(id, params)

          settle(response, result, LINKED, tasks_path(request)) do |errors|
            refuse(request, response, kind: Blog::Types::Text[params[:kind]], errors:)
          end
        end
      end
    end
  end
end
