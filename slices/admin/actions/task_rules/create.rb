# frozen_string_literal: true

module Admin
  module Actions
    module TaskRules
      class Create < Action
        ADDED = "task_rules_page.toasts.added"

        include Deps[
          "operations.build_tagging_page",
          save_task_rule: "tasks.operations.save_task_rule",
          tagging_view: "ui.views.settings.tagging",
        ]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:rule]]

          settle(response, save_task_rule.call(params), ADDED, Helpers::TagList.rules(routes)) do |errors|
            adding = { errors:, **UI::Components::TaskRules::List.typed(params) }
            unprocessable(response, tagging_view, **build_tagging_page.call(rules: { adding: }))
          end
        end
      end
    end
  end
end
