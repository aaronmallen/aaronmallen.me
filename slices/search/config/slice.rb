# frozen_string_literal: true

module Search
  class Slice < Hanami::Slice
    export %w[repos.search_queries]
  end
end
