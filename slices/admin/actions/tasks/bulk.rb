# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Bulk < TaskBulkAction
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
          act_on_tasks: "tasks.operations.act_on_tasks",
          count_tasks: "operations.count_tasks",
        ]

        private

        def act(params) = act_on_tasks.call(params)

        def back(request)
          back_here(request) || list_path(request)
        end

        def details(request)
          { **super, list: Helpers::TaskLists::NAMES[request.params[:to]]&.then { i18n.t!(it) } }
        end

        def list_path(request)
          query = Blog::Types::TrimmedText[request.params[:q]]
          tab = task_tab(request)
          page = landing(request) { it.offset >= count_tasks.call(tab:, query:).value_or(0) }
          pool = request.params[:pool]&.then { { pool: Blog::Types::TaskListParam[it] } }

          routes.path(:admin_tasks, filter: tab, **pool, **(query.empty? ? {} : { q: query }),
                                    **Blog::Structs::Page.query(page))
        end
      end
    end
  end
end
