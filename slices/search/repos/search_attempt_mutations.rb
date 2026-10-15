# frozen_string_literal: true

module Search
  module Repos
    class SearchAttemptMutations < Blog::DB::Repo
      root :search_attempts

      def claim(...) = search_attempts.claim(...)

      def delete_before(time) = search_attempts.made_before(time).delete
    end
  end
end
