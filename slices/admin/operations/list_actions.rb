# frozen_string_literal: true

module Admin
  module Operations
    class ListActions
      Entry = Data.define(:name, :icon, :route, :params, :dialog, :shows, :post, :needs, :from) do
        def initialize(
          name:, icon:, route: nil, params: Blog::Constants::EMPTY_HASH, dialog: nil, shows: nil, post: false,
          needs: nil, from: nil
        )
          super
        end

        def shows?(current_path) = shows.nil? || shows.call(current_path)
      end

      ALL = [
        Entry.new(
          name: :create_task, icon: "fa-plus", route: :admin_new_task, dialog: UI::Components::Tasks::CreateDialog::ID,
        ),
        Entry.new(
          name: :create_journal_entry, icon: "fa-pen", route: :admin_journal,
          params: { write: Blog::Constants::CHECKED },
        ),
        Entry.new(name: :start_task, icon: "fa-play", post: true, needs: :start),
        Entry.new(name: :complete_task, icon: "fa-check", post: true, needs: :complete),
        Entry.new(
          name: :complete_task_in_progress, icon: "fa-check", post: true, needs: :no_task,
          from: :admin_tasks_in_progress,
        ),
      ].freeze

      include Deps["routes"]

      def call(current_path:)
        ALL.select { it.shows?(current_path) }.map do |entry|
          Structs::Action.new(
            name: entry.name, icon: entry.icon, path: path(entry.route, entry.params), dialog: entry.dialog,
            post: entry.post, needs: entry.needs, from: path(entry.from),
          )
        end
      end

      private

      def path(route, params = Blog::Constants::EMPTY_HASH) = route && routes.path(route, **params)
    end
  end
end
