# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class Bulk < TaskBulkAction
        DONE = "projects_page.toasts.bulk.moved"
        FAILED = "projects_page.toasts.bulk.failed"
        INVALID = "projects_page.toasts.bulk.invalid"
        REASONS = %i[not_found].freeze

        include Deps[set_tasks_column: "tasks.operations.set_tasks_column"]

        private

        def act(params) = set_tasks_column.call(params)

        def back(request) = back_here(request) || routes.path(:admin_project, id: record_id(request))

        def done(request, response, records)
          column = UI::Components::Projects::BoardCard::NAMES[request.params[:to]]

          toast(response, DONE, count: records.size, column: i18n.t!(column))
        end
      end
    end
  end
end
