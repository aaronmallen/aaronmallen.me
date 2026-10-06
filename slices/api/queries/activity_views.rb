# frozen_string_literal: true

module API
  module Queries
    class ActivityViews
      POST = Blog::Types::ActivityKind["post"]

      include Deps[views_by_path: "analytics.queries.views_by_path"]

      def call(rows) = rows.any? { it.type == POST } ? views_by_path.call : Blog::Constants::EMPTY_HASH
    end
  end
end
