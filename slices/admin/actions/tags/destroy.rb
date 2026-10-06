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

          result = remove_tag.call(record_id(request), scope:)
          path = routes.path(:admin_tags, scope:)

          case result
          in Failure[:last_tag_of_rules, patterns]
            toast(response, KEPT, count: patterns.size, rules: patterns.join(SEPARATOR))
            response.redirect_to(path)
          else settle(response, result, REMOVED, path)
          end
        end
      end
    end
  end
end
