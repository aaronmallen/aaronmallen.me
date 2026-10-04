# frozen_string_literal: true

module Media
  module Queries
    class PublishedPhoto
      include Deps[photo_repo: "repos.photo_repo"]

      def call(key) = photo_repo.published(key)
    end
  end
end
