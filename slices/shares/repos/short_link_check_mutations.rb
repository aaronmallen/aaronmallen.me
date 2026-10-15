# frozen_string_literal: true

module Shares
  module Repos
    class ShortLinkCheckMutations < Blog::DB::Repo
      root :short_link_checks

      def forget_stale = short_link_checks.stale(short_links.select(:id, :destination).dataset.unordered).delete

      def record(**) = short_link_checks.record(**)
    end
  end
end
