# frozen_string_literal: true

module Admin
  module Actions
    module TaskTagRules
      class Create < Action
        ADDED = "task_tag_rules_page.toasts.added"
        TYPED = UI::Views::TaskTagRules::Index::TYPED

        include Deps[
          index_view: "ui.views.task_tag_rules.index",
          save_task_tag_rule: "tasks.operations.save_task_tag_rule",
          task_tag_rules: "tasks.queries.task_tag_rules",
        ]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:rule]]

          case save_task_tag_rule.call(params)
          in Success(_) then added(response)
          in Failure[:invalid, errors] then invalid(response, params, errors)
          else halt 500
          end
        end

        private

        def added(response)
          toast(response, ADDED)
          response.redirect_to(routes.path(:admin_task_tag_rules))
        end

        def invalid(response, params, errors)
          adding = { errors:, **TYPED.to_h { [it, Blog::Types::Text[params[it]]] } }

          response.status = 422
          response.render(index_view, adding:, editing: nil, rules: task_tag_rules.call)
        end
      end
    end
  end
end
