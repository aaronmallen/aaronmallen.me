Feature: Slice exports cop
  The Hanami/SliceExports cop lets a slice export read repos and operations, and nothing that writes or
  reaches past them.

  Scenario: The slice exports cop passes read repos and operations
    When I run "bundle exec rubocop --config .config/rubocop.yml --only Hanami/SliceExports --stdin slices/demo/config/slice.rb" with:
      """
      module Demo
        class Slice < Hanami::Slice
          export %w[repos.queries repos.post_queries operations.save_post]
        end
      end
      """
    Then it succeeds

  Scenario: The slice exports cop fails on each forbidden key
    When I run "bundle exec rubocop --config .config/rubocop.yml --only Hanami/SliceExports --stdin slices/demo/config/slice.rb" with:
      """
      module Demo
        class Slice < Hanami::Slice
          export %w[operations.save_post repos.mutations repos.post_mutations repos.post_repo queries.by_id relations.posts]
        end
      end
      """
    Then it fails
    And the output includes "repos.mutations matches ForbiddenExports"
    And the output includes "repos.post_mutations matches ForbiddenExports"
    And the output includes "repos.post_repo matches ForbiddenExports"
    And the output includes "queries.by_id matches ForbiddenExports"
    And the output includes "relations.posts matches ForbiddenExports"
