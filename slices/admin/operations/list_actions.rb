# frozen_string_literal: true

module Admin
  module Operations
    class ListActions
      Entry = Data.define(:name, :icon, :route, :params, :dialog, :shows) do
        def initialize(name:, icon:, route:, params: Blog::Constants::EMPTY_HASH, dialog: nil, shows: nil)
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
      ].freeze

      include Deps["routes"]

      def call(current_path:)
        ALL.select { it.shows?(current_path) }.map do |entry|
          Structs::Action.new(
            name: entry.name, icon: entry.icon, path: routes.path(entry.route, **entry.params), dialog: entry.dialog,
          )
        end
      end
    end
  end
end
