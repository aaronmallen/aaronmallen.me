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
        LISTS = {
          Blog::Types::TaskFilter["today"] => "tasks_page.toasts.bulk.lists.today",
          Blog::Types::TaskFilter["next"] => "tasks_page.toasts.bulk.lists.next",
          Blog::Types::TaskFilter["someday"] => "tasks_page.toasts.bulk.lists.someday",
          Blog::Types::TaskFilter["external"] => "tasks_page.toasts.bulk.lists.external",
        }.freeze
        REASONS = %i[closed not_found].freeze

        include Redirect
        include Deps[
          "settings",
          build_tasks_page: "operations.build_tasks_page",
          operation: "tasks.operations.act_on_tasks",
          task_queries: "tasks.repos.task_queries",
        ]

        private

        def back(request)
          query = Blog::Types::TrimmedText[request.params[:q]]
          tab = task_tab(request)
          page = landing(request) { build_tasks_page.call(page: it, tab:, query:).failure? }

          routes.path(:admin_tasks, filter: tab, **(query.empty? ? {} : { q: query }), **Blog::Page.query(page))
        end

        def details(request)
          {
            list: LISTS[request.params[:to]]&.then { i18n.t!(it) },
            tag: Blog::Types::Nullable::Tag[request.params[:tag]],
          }
        end

        def named(id) = { task: ["#{KEY}#{id}", task_queries.detailed(id)&.title].compact.join(" ") }

        def refusal(errors)
          case errors
          in { to: } then "to_#{Blog::Contract::BLANK}"
          in { tag: [message, *] } then "tag_#{message}"
          else Blog::Contract::FORMAT
          end
        end
      end
    end
  end
end
