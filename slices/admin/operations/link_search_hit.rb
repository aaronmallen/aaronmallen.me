# frozen_string_literal: true

module Admin
  module Operations
    class LinkSearchHit
      WORK = Blog::Types::ProjectFilter["work"]

      include Deps["routes"]

      def call(hit)
        id = hit.source_id

        case hit.kind
        when "task" then routes.path(:admin_task, id:)
        when "post" then routes.path(:admin_edit_post, id:)
        when "commit" then routes.path(:admin_commit, id:)
        when "project" then routes.path(:admin_edit_project, id:)
        when "person" then routes.path(:admin_edit_person, id:)
        else listed(hit)
        end
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
