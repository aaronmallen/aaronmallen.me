# frozen_string_literal: true

module Admin
  module Operations
    class ListSections
      KINDS = Blog::Helpers::RecordKinds
      ALL = [
        %i[today today fa-sun admin_root].freeze,
        [:tasks, :tasks, KINDS.icon("task"), :admin_tasks].freeze,
        %i[calendar tasks fa-calendar-days admin_calendar].freeze,
        [:journal, :journal, KINDS.icon("journal_entry"), :admin_journal].freeze,
        [:decisions, :journal, KINDS.icon("decision"), :admin_decisions].freeze,
        %i[review journal fa-magnifying-glass-chart admin_review].freeze,
        [:posts, :publish, KINDS.icon("post"), :admin_posts].freeze,
        [:social, :publish, KINDS.icon("social_post"), :admin_social].freeze,
        [:projects, :publish, KINDS.icon("project"), :admin_projects].freeze,
        %i[inbox inbox fa-inbox admin_inbox].freeze,
        %i[messages inbox fa-envelope admin_messages].freeze,
        %i[webmentions inbox fa-at admin_webmentions].freeze,
        %i[analytics insights fa-chart-simple admin_analytics].freeze,
        %i[activity insights fa-timeline admin_activity].freeze,
        %i[time insights fa-clock admin_time].freeze,
        %i[search insights fa-magnifying-glass admin_search].freeze,
        %i[tags settings fa-tag admin_tags].freeze,
        %i[people settings fa-address-book admin_people].freeze,
        %i[task_rules settings fa-wand-magic-sparkles admin_task_rules].freeze,
        %i[webmention_settings settings fa-at admin_webmentions webmention-settings].freeze,
        %i[tokens settings fa-key admin_tokens].freeze,
        %i[services settings fa-link admin_services].freeze,
        %i[clients settings fa-plug admin_clients].freeze,
        %i[security settings fa-shield-halved admin_security].freeze,
      ].freeze

      JUMPS = { today: "t", tasks: "k", journal: "j", posts: "p", activity: "a" }.freeze
      ROOT = :today

      include Deps["routes", inbox_queries: "api.repos.inbox_queries"]

      def call(current_path:)
        found = located
        current = found.select { |(name, _, _, path)| covers?(name, path, current_path) }.map(&:last).max_by(&:length)

        found.map do |(name, group, icon, path)|
          Structs::Section.new(
            name:, group:, icon: icon.to_s, path:, count: count_for(name), current: path == current, jump: JUMPS[name],
          )
        end
      end

      private

      def count_for(name) = name == :inbox ? inbox_queries.unseen_count : 0

      def covers?(name, path, current_path)
        return current_path == path if name == ROOT

        current_path == path || current_path.start_with?("#{path}/")
      end

      def located
        ALL.map do |(name, group, icon, route, anchor)|
          [name, group, icon, [routes.path(route), anchor].compact.join("#")]
        end
      end
    end
  end
end
