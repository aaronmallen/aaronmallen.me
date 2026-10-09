# frozen_string_literal: true

module Admin
  module Operations
    class LinkSearchHit
      PAGES = {
        "commit" => :admin_commit, "decision" => :admin_decision, "person" => :admin_edit_person,
        "post" => :admin_edit_post, "project" => :admin_edit_project, "pull_request" => :admin_pull_request,
        "task" => :admin_task,
      }.freeze
      WORK = Blog::Types::ProjectFilter["work"]

      include Deps["routes"]

      def call(hit)
        page = PAGES[hit.kind]

        page ? routes.path(page, id: hit.source_id) : listed(hit)
      end

      private

      def journal(day) = "#{routes.path(:admin_journal, to: day)}##{UI::Components::Journal::Day.anchor(day)}"

      def listed(hit)
        case hit.kind
          when "social" then routes.path(:admin_social, edit: hit.source_id)
          when "journal" then journal(hit.day)
          when "work" then routes.path(:admin_projects, filter: WORK)
          when "message" then routes.path(:admin_messages, status: hit.status)
          when "webmention" then routes.path(:admin_webmentions, status: hit.status)
        end
      end
    end
  end
end
