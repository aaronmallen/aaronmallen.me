# frozen_string_literal: true

module Admin
  module Actions
    module RecordLinks
      class Unlink < Action
        PAGES = {
          "artifact" => :admin_artifact, "commit" => :admin_commit, "decision" => :admin_decision,
          "memory_file" => :admin_memory_file, "post" => :admin_edit_post, "project" => :admin_edit_project,
          "pull_request" => :admin_pull_request,
        }.freeze
        SCOPED = "record_links.toasts.scoped"
        TASK = Blog::Types::RecordKind["task"]
        UNLINKED = {
          "decision" => "decisions_page.toasts.record_unlinked", "task" => "tasks_page.toasts.record_unlinked",
        }.freeze
        UNLINKED_RECORD = "record_links.toasts.unlinked"
        WORK = Blog::Types::ProjectFilter["work"]

        include Deps[unlink_records: "links.operations.unlink_records"]
        include Tasks::Redirect

        def handle(request, response)
          kind = request.params[:kind]
          id = record_id(request)
          path = record_path(request, kind, id) || halt(:not_found)

          result = unlink_records.call(kind, id, request.params[:other_kind], request.params[:other_id])
          toast = UNLINKED.fetch(kind, UNLINKED_RECORD)
          settle(response, result, toast, path) { toast_back(response, SCOPED, path) }
        end

        private

        def listed_path(params, kind, id)
          case kind
            when "journal_entry" then routes.path(:admin_journal, to: Blog::Types::DateParam[params[:to]], edit: id)
            when "social_post"
              routes.path(:admin_social, filter: Blog::Types::SocialQueueParam[params[:filter]], edit: id)
            when "work_entry" then routes.path(:admin_projects, filter: WORK, edit: id)
          end
        end

        def record_path(request, kind, id)
          return routes.path(PAGES.fetch(kind), id:) if PAGES.key?(kind)
          return tasks_path(request) if kind == TASK

          listed_path(request.params, kind, id)
        end
      end
    end
  end
end
