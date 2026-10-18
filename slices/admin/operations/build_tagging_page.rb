# frozen_string_literal: true

module Admin
  module Operations
    class BuildTaggingPage
      PRIVATE = Blog::Types::TagScope["private"]
      SCOPE = Blog::Types::TagScopeParam[nil]

      include Deps[
        "operations.build_settings_tabs",
        "operations.build_tags_page",
        tag_queries: "tags.repos.tag_queries",
        task_rule_queries: "tasks.repos.task_rule_queries",
      ]

      def call(tags: Blog::Constants::EMPTY_HASH, rules: Blog::Constants::EMPTY_HASH)
        found = task_rule_queries.all

        {
          tags: build_tags_page.call(scope: SCOPE, **tags),
          rules: {
            adding: UI::Components::TaskRules::List::BLANK, editing: nil, **rules,
            rules: found, projects: task_rule_queries.project_choices, tags: tag_queries.all_in(PRIVATE, mail: false),
          },
          tabs: build_settings_tabs.call(tagging: found.size),
        }
      end
    end
  end
end
