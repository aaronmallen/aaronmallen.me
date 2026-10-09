# frozen_string_literal: true

module Record
  module Structs
    class PullRequest < Blog::DB::Struct
      def moved_at = merged_at || closed_at || ready_at || created_at

      def state
        Blog::Types::PullRequestState[
          if merged_at then "merged"
          elsif closed_at then "closed"
          elsif ready_at then "open"
          else "draft"
          end,
        ]
      end
    end
  end
end
