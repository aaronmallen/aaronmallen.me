# frozen_string_literal: true

module Admin
  module Operations
    class ListActions
      Entry = Data.define(:name, :icon, :route, :params, :dialog, :post, :needs, :from, :from_params, :key) do
        def initialize(
          name:, icon:, route: nil, params: Blog::Constants::EMPTY_HASH, dialog: nil, post: false, needs: nil,
          from: nil, from_params: Blog::Constants::EMPTY_HASH, key: nil
        )
          super
        end
      end

      ALL = [
        Entry.new(
          name: :create_task, icon: "fa-list-check", route: :admin_new_task,
          dialog: UI::Components::Tasks::CreateDialog::ID, key: "c",
        ),
        Entry.new(name: :create_decision, icon: "fa-scale-balanced", route: :admin_new_decision),
        Entry.new(
          name: :create_journal_entry, icon: "fa-feather", route: :admin_journal,
          params: { write: Blog::Types::CHECKED }, dialog: UI::Components::Journal::WriteDialog::ID, key: "w",
        ),
        Entry.new(name: :new_post, icon: "fa-file-lines", route: :admin_new_post),
        Entry.new(
          name: :new_social_post, icon: "fa-paper-plane", route: :admin_social,
          params: { write: Blog::Types::CHECKED },
        ),
        Entry.new(name: :start_task, icon: "fa-play", post: true, needs: :start),
        Entry.new(name: :complete_task, icon: "fa-check", post: true, needs: :complete),
        Entry.new(name: :pause_task, icon: "fa-pause", post: true, needs: :pause),
        Entry.new(
          name: :complete_task_in_progress, icon: "fa-check", post: true, needs: :no_task,
          from: :admin_tasks_in_progress,
        ),
        Entry.new(
          name: :pause_task_in_progress, icon: "fa-pause", post: true, needs: :no_task,
          from: :admin_tasks_in_progress, from_params: { act: Blog::Types::TaskAct["pause"] },
        ),
      ].freeze

      include Deps["routes"]

      def call
        ALL.map do |entry|
          Structs::Action.new(
            name: entry.name, icon: entry.icon, path: path(entry.route, entry.params), dialog: entry.dialog,
            post: entry.post, needs: entry.needs, from: path(entry.from, entry.from_params), key: entry.key,
          )
        end
      end

      private

      def path(route, params = Blog::Constants::EMPTY_HASH) = route && routes.path(route, **params)
    end
  end
end
