# frozen_string_literal: true

module Admin
  module Actions
    module Mail
      class MakeTask < Action
        ALREADY = "mail_page.toasts.already_tasked"
        INBOX = Blog::Types::TaskOrigin["inbox"]
        MADE = "mail_page.toasts.tasked"
        UNARCHIVED = "mail_page.toasts.tasked_unarchived"
        UNTITLED = "mail_page.toasts.untitled"

        include Redirect
        include Deps[
          make_mail_task: "operations.make_mail_task",
          task_queries: "tasks.repos.task_queries",
          thread_queries: "mail.repos.thread_queries",
        ]

        def handle(request, response)
          id = record_id(request)

          case made(id, Blog::Types::Fields[request.params[:task]])
            in Success(task) then toast(response, MADE, key: label(task))
            in Failure(:not_found) then halt 404
            in Failure[:unarchived, task] then toast(response, UNARCHIVED, key: label(task))
            in Failure(:tasked) then toast(response, ALREADY)
            in Failure[:invalid, _] then toast(response, UNTITLED)
            else halt 500
          end
          response.redirect_to(back(request, id))
        end

        private

        def back(request, id)
          return routes.path(:admin_inbox) if request.params[:origin] == INBOX

          listed(request, thread: id)
        end

        def label(task) = task_queries.by_id(task.id).label

        def made(id, fields)
          make_mail_task.call(
            id, { title: fields[:title] },
            filter: Blog::Types::TaskFilterParam[fields[:list]], archive: fields[:archive] == Blog::Constants::CHECKED,
          )
        end
      end
    end
  end
end
