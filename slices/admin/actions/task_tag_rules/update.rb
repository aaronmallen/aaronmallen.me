# frozen_string_literal: true

module Admin
  module Actions
    module TaskTagRules
      class Update < Action
        BLANK = UI::Views::TaskTagRules::Index::BLANK
        SAVED = "task_tag_rules_page.toasts.saved"
        TYPED = UI::Views::TaskTagRules::Index::TYPED

        include Deps[
          index_view: "ui.views.task_tag_rules.index",
          save_task_tag_rule: "tasks.operations.save_task_tag_rule",
          task_tag_rules: "tasks.queries.task_tag_rules",
        ]

        def handle(request, response)
          id = record_id(request)
          params = Blog::Types::Fields[request.params[:rule]]

          case save_task_tag_rule.call(params, id:)
          in Success(_) then saved(response)
          in Failure(:not_found) then halt 404
          in Failure[:invalid, errors] then invalid(response, id, params, errors)
          else halt 500
          end
        end

        private

        def invalid(response, id, params, errors)
          editing = { errors:, id:, **TYPED.to_h { [it, Blog::Types::Text[params[it]]] } }

          response.status = 422
          response.render(index_view, adding: BLANK, editing:, rules: task_tag_rules.call)
        end

        def saved(response)
          toast(response, SAVED)
          response.redirect_to(routes.path(:admin_task_tag_rules))
        end
      end
    end
  end
end
