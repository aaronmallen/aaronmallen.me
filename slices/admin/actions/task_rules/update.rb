# frozen_string_literal: true

module Admin
  module Actions
    module TaskRules
      class Update < Action
        SAVED = "task_rules_page.toasts.saved"

        include Deps[
          "operations.build_tagging_page",
          save_task_rule: "tasks.operations.save_task_rule",
          tagging_view: "ui.views.settings.tagging",
        ]

        def handle(request, response)
          id = record_id(request)
          params = Blog::Types::Fields[request.params[:rule]]

          result = save_task_rule.call(params, id:)

          settle(response, result, SAVED, Helpers::TagList.rules(routes)) do |errors|
            editing = { errors:, id:, **UI::Components::TaskRules::List.typed(params) }
            unprocessable(response, tagging_view, **build_tagging_page.call(rules: { editing: }))
          end
        end
      end
    end
  end
end
