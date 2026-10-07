# frozen_string_literal: true

module Search
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/search"), namespace: Search)

    export %w[repos.search_queries]
  end
end
