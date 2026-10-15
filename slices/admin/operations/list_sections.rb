# frozen_string_literal: true

module Admin
  module Operations
    class ListSections
      KINDS = Blog::Helpers::RecordKinds
      ALL = [
        %i[today today fa-sun admin_root].freeze,
        [:tasks, :tasks, KINDS.icon("task"), :admin_tasks].freeze,
        %i[calendar tasks fa-calendar-days admin_calendar].freeze,
        [:projects, :tasks, KINDS.icon("project"), :admin_projects].freeze,
        [:journal, :journal, KINDS.icon("journal_entry"), :admin_journal].freeze,
        [:decisions, :journal, KINDS.icon("decision"), :admin_decisions].freeze,
        %i[review journal fa-magnifying-glass-chart admin_review].freeze,
        [:posts, :publish, KINDS.icon("post"), :admin_posts].freeze,
        [:social, :publish, KINDS.icon("social_post"), :admin_social].freeze,
        %i[files publish fa-paperclip admin_files].freeze,
        %i[links publish fa-link admin_links].freeze,
        %i[inbox inbox fa-inbox admin_inbox].freeze,
        %i[mail inbox fa-envelope admin_mail].freeze,
        %i[webmentions inbox fa-at admin_webmentions].freeze,
        %i[analytics insights fa-chart-simple admin_analytics].freeze,
        %i[activity insights fa-timeline admin_activity].freeze,
        %i[health insights fa-heart-pulse admin_health].freeze,
        %i[time insights fa-clock admin_time].freeze,
        %i[tags settings fa-tag admin_tags].freeze,
        %i[people settings fa-address-book admin_people].freeze,
        %i[task_rules settings fa-wand-magic-sparkles admin_task_rules].freeze,
        %i[webmention_settings settings fa-at admin_webmention_settings].freeze,
        %i[tokens settings fa-key admin_tokens].freeze,
        %i[services settings fa-link admin_services].freeze,
        %i[clients settings fa-plug admin_clients].freeze,
        %i[security settings fa-shield-halved admin_security].freeze,
      ].freeze

      ALSO = { analytics: { performance: :admin_performance } }.freeze
      JUMPS = { today: "t", tasks: "k", journal: "j", posts: "p", activity: "a" }.freeze
      ROOT = :today

      include Deps["routes"]

      def call(current_path:, inbox:)
        found = located
        current = found.select { |(name, _, _, path)| covers?(name, path, current_path) }.map(&:last).max_by(&:length)

        found.map do |(name, group, icon, path)|
          count = name == :inbox ? inbox : 0

          Structs::Section.new(
            name:, group:, icon: icon.to_s, path:, count:, current: path == current, jump: JUMPS[name],
            also: ALSO.fetch(name, Blog::Constants::EMPTY_HASH).keys,
          )
        end
      end

      private

      def covers?(name, path, current_path)
        return current_path == path if name == ROOT

        [path, *ALSO.fetch(name, Blog::Constants::EMPTY_HASH).values.map { routes.path(it) }].any? do |covered|
          current_path == covered || current_path.start_with?("#{covered}/")
        end
      end

      def located = ALL.map { |(name, group, icon, route)| [name, group, icon, routes.path(route)] }
    end
  end
end
