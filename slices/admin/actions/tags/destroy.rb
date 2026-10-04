# frozen_string_literal: true

module Admin
  module Actions
    module Tags
      class Destroy < Action
        KEPT = "tags_page.toasts.kept"
        REMOVED = "tags_page.toasts.removed"
        SEPARATOR = ", "

        include Deps[remove_tag: "tags.operations.remove_tag"]

        def handle(request, response)
          scope = Blog::Types::TagScopeParam[request.params[:scope]]

          case remove_tag.call(record_id(request), scope:)
          in Success(_) then toast(response, REMOVED)
          in Failure[:last_tag_of_rules, patterns]
            toast(response, KEPT, count: patterns.size, rules: patterns.join(SEPARATOR))
          in Failure(:not_found) then halt 404
          else halt 500
          end

          response.redirect_to(routes.path(:admin_tags, scope:))
        end
      end
    end
  end
end
