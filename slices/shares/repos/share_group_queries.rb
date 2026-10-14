# frozen_string_literal: true

module Shares
  module Repos
    class ShareGroupQueries < Blog::DB::Repo
      def find(id) = share_groups.with_code.by_pk(id).combine(:share_group_files).one
    end
  end
end
