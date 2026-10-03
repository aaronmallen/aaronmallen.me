# frozen_string_literal: true

module Admin
  module Operations
    class ListSections
      ALL = [
        %i[today daily fa-sun admin_root].freeze,
        %i[tasks daily fa-list-check admin_tasks].freeze,
        %i[journal daily fa-feather admin_journal].freeze,
        %i[calendar daily fa-calendar-days admin_calendar].freeze,
        %i[posts publish fa-file-lines admin_posts].freeze,
        %i[social publish fa-paper-plane admin_social].freeze,
        %i[projects publish fa-cube admin_projects].freeze,
        %i[messages inbox fa-envelope admin_messages].freeze,
        %i[webmentions inbox fa-at admin_webmentions].freeze,
        %i[activity insights fa-timeline admin_activity].freeze,
        %i[analytics insights fa-chart-simple admin_analytics].freeze,
        %i[tags settings fa-tag admin_tags].freeze,
        %i[people settings fa-address-book admin_people].freeze,
        %i[clients settings fa-plug admin_clients].freeze,
        %i[tokens settings fa-key admin_tokens].freeze,
      ].freeze

      ROOT = :today

      include Deps[
        "operations.count_unread_messages",
        "routes",
        pending_webmention_count: "social.queries.pending_webmention_count",
      ]

      def call(current_path:)
        found = located
        current = found.select { |(name, _, _, path)| covers?(name, path, current_path) }.map(&:last).max_by(&:length)

        found.map do |(name, group, icon, path)|
          Structs::Section.new(name:, group:, icon: icon.to_s, path:, count: count_for(name), current: path == current)
        end
      end

      private

      def count_for(name)
        case name
        when :messages then count_unread_messages.call
        when :webmentions then pending_webmention_count.call
        else 0
        end
      end

      def covers?(name, path, current_path)
        return current_path == path if name == ROOT

        current_path == path || current_path.start_with?("#{path}/")
      end

      def located
        ALL.map { |(name, group, icon, route)| [name, group, icon, routes.path(route)] }
      end
    end
  end
end
