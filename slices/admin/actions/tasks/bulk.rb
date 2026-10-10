# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Bulk < BulkAction
        DONE = {
          Blog::Types::TaskBulkAction["cancel"] => "tasks_page.toasts.bulk.canceled",
          Blog::Types::TaskBulkAction["complete"] => "tasks_page.toasts.bulk.completed",
          Blog::Types::TaskBulkAction["delete"] => "tasks_page.toasts.bulk.deleted",
          Blog::Types::TaskBulkAction["move"] => "tasks_page.toasts.bulk.moved",
          Blog::Types::TaskBulkAction["tag"] => "tasks_page.toasts.bulk.tagged",
          Blog::Types::TaskBulkAction["untag"] => "tasks_page.toasts.bulk.untagged",
        }.freeze
        FAILED = "tasks_page.toasts.bulk.failed"
        INVALID = "tasks_page.toasts.bulk.invalid"
        REASONS = %i[closed not_found].freeze

        include Redirect
        include Deps[
          build_tasks_page: "operations.build_tasks_page",
          operation: "tasks.operations.act_on_tasks",
          task_queries: "tasks.repos.task_queries",
        ]

        private

        def back(request)
          query = Blog::Types::TrimmedText[request.params[:q]]
          tab = task_tab(request)
          page = landing(request) { build_tasks_page.call(page: it, tab:, query:).failure? }

          routes.path(:admin_tasks, filter: tab, **(query.empty? ? {} : { q: query }), **Blog::Structs::Page.query(page))
        end

        def details(request)
          { **super, list: Helpers::TaskLists::NAMES[request.params[:to]]&.then { i18n.t!(it) } }
        end

        def named(id)
          { task: [UI::Components::RecordKey.key(id), task_queries.detailed(id)&.title].compact.join(" ") }
        end

        def refusal(errors)
          errors.key?(:to) ? "to_#{Blog::Contract::BLANK}" : super
        end
      end
    end
  end
end
