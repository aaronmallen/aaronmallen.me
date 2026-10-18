# frozen_string_literal: true

module Admin
  module Operations
    class BuildTaggingPage
      PRIVATE = Blog::Types::TagScope["private"]
      SCOPE = Blog::Types::TagScopeParam[nil]

      include Deps[
        "operations.build_tags_page",
        tag_queries: "tags.repos.tag_queries",
        task_rule_queries: "tasks.repos.task_rule_queries",
      ]

      def call(tags: Blog::Constants::EMPTY_HASH, rules: Blog::Constants::EMPTY_HASH)
        {
          tags: build_tags_page.call(scope: SCOPE, **tags),
          rules: {
            adding: UI::Components::TaskRules::List::BLANK, editing: nil, **rules,
            rules: task_rule_queries.all, projects: task_rule_queries.project_choices,
            tags: tag_queries.all_in(PRIVATE, mail: false),
          },
        }
      end
    end
  end
end
