# frozen_string_literal: true

module Admin
  module Actions
    module Tags
      class Destroy < Action
        IN_USE = "tags_page.toasts.in_use"
        REMOVED = "tags_page.toasts.removed"

        include Deps[remove_tag: "tags.operations.remove_tag"]

        def handle(request, response)
          scope = Blog::Types::TagScopeParam[request.params[:scope]]

          case remove_tag.call(record_id(request), scope:)
          in Success(_) then done(response, scope, REMOVED)
          in Failure(:not_found) then halt 404
          in Failure[:in_use, held] then done(response, scope, IN_USE, count: held)
          else halt 500
          end
        end

        private

        def done(response, scope, key, **)
          toast(response, key, **)
          response.redirect_to(routes.path(:admin_tags, scope:))
        end
      end
    end
  end
end
