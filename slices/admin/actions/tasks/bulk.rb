# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Bulk < Action
        BLANK = "blank"
        DONE = {
          Blog::Types::TaskBulkAction["cancel"] => "tasks_page.toasts.bulk.canceled",
          Blog::Types::TaskBulkAction["complete"] => "tasks_page.toasts.bulk.completed",
          Blog::Types::TaskBulkAction["delete"] => "tasks_page.toasts.bulk.deleted",
        }.freeze
        FAILED = "tasks_page.toasts.bulk.failed"
        FORMAT = "format"
        INVALID = "tasks_page.toasts.bulk.invalid"
        KEY = "#"
        LONG = "long"
        REASONS = %i[closed not_found].freeze

        include Redirect
        include Deps[
          "settings",
          act_on_tasks: "tasks.operations.act_on_tasks",
          build_tasks_page: "operations.build_tasks_page",
          task_by_id: "tasks.queries.task_by_id",
        ]

        def handle(request, response)
          case act_on_tasks.call(request.params.to_h)
          in Success[*tasks] then toast(response, DONE.fetch(request.params[:act]), count: tasks.size)
          in Failure[:record, id, reason] then failed(response, id, reason)
          in Failure[:invalid, errors] then invalid(response, errors)
          else halt 500
          end

          response.redirect_to(back(request))
        end

        private

        def back(request)
          query = Blog::Types::TrimmedText[request.params[:q]]
          tab = task_tab(request)
          page = landing(request, tab, query)

          routes.path(:admin_tasks, filter: tab, **(query.empty? ? {} : { q: query }), **Blog::Page.query(page))
        end

        def failed(response, id, reason)
          task = task_by_id.call(id)
          name = ["#{KEY}#{id}", task&.title].compact.join(" ")
          code = REASONS.include?(reason) ? reason : :other

          toast(response, "#{FAILED}.#{code}", task: name)
        end

        def invalid(response, errors)
          toast(response, "#{INVALID}.#{refusal(errors[:ids])}")
        end

        def landing(request, tab, query)
          number = Blog::Types::PageParam.call(request.params[:page]) { 1 }
          return number if number == 1

          page = Blog::Page.new(number:, size: settings.page_size[:admin])
          build_tasks_page.call(page:, tab:, query:).failure? ? number - 1 : number
        end

        def refusal(errors)
          case errors
          in [LONG, *] then LONG
          in [::String, *] then BLANK
          else FORMAT
          end
        end
      end
    end
  end
end
