# frozen_string_literal: true

module Search
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/search"), namespace: Search)

    import keys: %w[operations.hash_visitor], from: :analytics

    export %w[operations.claim_search_attempt repos.public_search_queries repos.search_queries]
  end
end
