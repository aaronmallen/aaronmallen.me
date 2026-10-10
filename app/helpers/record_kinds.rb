# frozen_string_literal: true

module Blog
  module Helpers
    module RecordKinds
      Row = Data.define(:kind, :icon, :route, :label, :search_kind)

      LABELS = "ui.components.record_links.kinds"
      ROWS = {
        "commit" => ["fa-code-commit", :admin_commit, "commit"],
        "decision" => ["fa-scale-balanced", :admin_decision, "decision"],
        "journal_entry" => ["fa-feather", :admin_journal, "journal"],
        "post" => ["fa-file-lines", :admin_edit_post, "post"],
        "project" => ["fa-cube", :admin_edit_project, "project"],
        "pull_request" => ["fa-code-pull-request", :admin_pull_request, "pull_request"],
        "social_post" => ["fa-paper-plane", :admin_social, "social"],
        "task" => ["fa-list-check", :admin_task, "task"],
        "work_entry" => ["fa-briefcase", :admin_projects, "work"],
      }.freeze
      JOURNAL_ENTRY = Types::RecordKind["journal_entry"]
      SOCIAL_POST = Types::RecordKind["social_post"]
      WORK = Types::ProjectFilter["work"]
      WORK_ENTRY = Types::RecordKind["work_entry"]
      private_constant :LABELS, :ROWS, :JOURNAL_ENTRY, :SOCIAL_POST, :WORK, :WORK_ENTRY

      ALL = Types::RecordKind.values.to_h do |kind|
        icon, route, search_kind = ROWS.fetch(kind)

        [kind, Row.new(kind:, icon:, route:, label: "#{LABELS}.#{kind}", search_kind: Types::SearchKind[search_kind])]
      end.freeze
      SEARCHED = ALL.values.to_h { [it.search_kind, it] }.freeze
      private_constant :SEARCHED

      module_function

      def fetch(kind) = ALL.fetch(kind)

      def icon(kind) = fetch(kind).icon

      def path(routes, kind, id:, day:)
        route = fetch(kind).route

        case kind
          when SOCIAL_POST then routes.path(route, edit: id)
          when JOURNAL_ENTRY then "#{routes.path(route, to: day)}#day-#{day.iso8601}"
          when WORK_ENTRY then routes.path(route, filter: WORK)
          else routes.path(route, id:)
        end
      end

      def searched(search_kind) = SEARCHED[search_kind]
    end
  end
end
