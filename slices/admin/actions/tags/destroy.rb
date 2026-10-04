# frozen_string_literal: true

module Admin
  module Actions
    module Tags
      class Destroy < Action
        REMOVED = "tags_page.toasts.removed"

        include Deps[remove_tag: "tags.operations.remove_tag"]

        def handle(request, response)
          scope = Blog::Types::TagScopeParam[request.params[:scope]]

          case remove_tag.call(record_id(request), scope:)
          in Success(_) then removed(response, scope)
          in Failure(:not_found) then halt 404
          else halt 500
          end
        end

        private

        def removed(response, scope)
          toast(response, REMOVED)
          response.redirect_to(routes.path(:admin_tags, scope:))
        end
      end
    end
  end
end
