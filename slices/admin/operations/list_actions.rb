# frozen_string_literal: true

module Admin
  module Operations
    class ListActions
      KINDS = Blog::Helpers::RecordKinds

      ALL = [
        {
          name: :create_task, icon: KINDS.icon("task"), route: :admin_new_task,
          dialog: UI::Components::Tasks::CreateDialog::ID, key: "c",
        },
        { name: :create_decision, icon: KINDS.icon("decision"), route: :admin_new_decision },
        {
          name: :create_journal_entry, icon: KINDS.icon("journal_entry"), route: :admin_journal,
          params: { write: Blog::Constants::CHECKED }, dialog: UI::Components::Journal::WriteDialog::ID, key: "w",
        },
        { name: :new_post, icon: KINDS.icon("post"), route: :admin_new_post },
        {
          name: :new_social_post, icon: KINDS.icon("social_post"), route: :admin_social,
          params: { write: Blog::Constants::CHECKED },
        },
        { name: :new_artifact, icon: KINDS.icon("artifact"), route: :admin_new_artifact },
        {
          name: :plan_tomorrow, icon: "fa-calendar", route: :admin_tasks,
          params: { filter: Blog::Types::TaskTab["upcoming"] },
        },
        { name: :import_commits, icon: "fa-rotate", route: :admin_import_commits, post: true },
        { name: :sync_issues, icon: KINDS.icon("pull_request"), route: :admin_sync_issues, post: true },
        { name: :keyboard_shortcuts, icon: "fa-keyboard", click: "[data-key-help-open]", key: "?" },
        {
          name: :toggle_theme, icon: "fa-circle-half-stroke", click: "[data-theme-choice][aria-pressed='false']",
        },
        {
          name: :activate_maintenance, icon: "fa-person-digging", route: :admin_activate_maintenance, post: true,
          confirm: true,
        },
        { name: :start_task, icon: "fa-play", post: true, needs: :start },
        { name: :complete_task, icon: "fa-check", post: true, needs: :complete },
        { name: :pause_task, icon: "fa-pause", post: true, needs: :pause },
        {
          name: :complete_task_in_progress, icon: "fa-check", post: true, needs: :no_task,
          from: :admin_tasks_in_progress,
        },
        {
          name: :pause_task_in_progress, icon: "fa-pause", post: true, needs: :no_task,
          from: :admin_tasks_in_progress, from_params: { act: Blog::Types::TaskAct["pause"] },
        },
      ].freeze

      include Deps["routes"]

      def call = @call ||= ALL.map { build(**it) }.freeze

      private

      def build(
        route: nil, params: Blog::Constants::EMPTY_HASH, from: nil, from_params: Blog::Constants::EMPTY_HASH, **
      )
        Structs::Action.new(**, path: path(route, params), from: path(from, from_params))
      end

      def path(route, params) = route && routes.path(route, **params)
    end
  end
end
