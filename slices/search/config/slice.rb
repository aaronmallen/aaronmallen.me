# frozen_string_literal: true

module Search
  class Slice < Hanami::Slice
    import keys: %w[operations.hash_visitor], from: :analytics

    import keys: %w[repos.task_label_queries], from: :tasks

    export %w[operations.claim_search_attempt repos.public_search_queries repos.search_queries]
  end
end
