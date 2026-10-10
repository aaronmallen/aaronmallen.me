# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Update < Action
        AGENT = Blog::Types::ContributorKind["agent"]
        CLOSED = "tasks_page.toasts.closed"
        FIELDS = %i[list note sprint_on tags title].freeze
        OWNER = { kind: Blog::Types::ContributorKind["owner"] }.freeze
        PARTED = "0"
        PAST = "tasks_page.toasts.sprint_past"
        SAVED = "tasks_page.toasts.saved"

        include Redirect
        include Deps[
          edit_view: "ui.views.tasks.edit",
          save_task: "tasks.operations.save_task",
          task_queries: "tasks.repos.task_queries",
        ]

        def handle(request, response)
          id = record_id(request)
          fields = Blog::Types::Fields[request.params[:task]]

          case save_task.call(id, form(id, fields))
            in Failure(:closed) then done(request, response, CLOSED)
            in Failure(:past) | Failure(:invalid) then done(request, response, PAST)
            in Failure[:invalid, errors] then invalid(request, response, id, fields, errors)
            in result then settle(response, result, SAVED, tasks_path(request))
          end
        end

        private

        def agent(row)
          row = Blog::Types::Fields[row]
          return if row[:keep] == PARTED

          agent, model = row.values_at(:agent, :model).map { Blog::Types::TrimmedText[it] }
          { kind: AGENT, agent:, model: } unless agent.empty? && model.empty?
        end

        def changed_credits(id, credits)
          if credits.nil? || credits.to_set == task_queries.detailed(id)&.credits&.to_set
            return Blog::Constants::EMPTY_HASH
          end

          { contributors: credits }
        end

        def credits(form)
          return unless form.is_a?(::Hash)

          owner = form[:owner] == Blog::Constants::CHECKED ? [OWNER] : Blog::Constants::EMPTY_ARRAY
          owner + Blog::Types::Fields[form[:agents]].values.filter_map { agent(it) }
        end

        def done(request, response, key)
          toast(response, key)
          response.redirect_to(tasks_path(request))
        end

        def form(id, fields)
          fields.except(:contributors).merge(changed_credits(id, credits(fields[:contributors])))
        end

        def invalid(request, response, id, fields, errors)
          task = task_queries.detailed(id) || halt(404)
          values = FIELDS.to_h { [it, Blog::Types::Text[fields[it]]] }
          credits = credits(fields[:contributors])
          values[:contributors] = credits if credits

          response.status = 422
          response.render(edit_view, task:, errors:, values:, **return_to(request))
        end
      end
    end
  end
end
