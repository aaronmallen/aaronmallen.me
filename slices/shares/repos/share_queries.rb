# frozen_string_literal: true

module Shares
  module Repos
    class ShareQueries < Blog::DB::Repo
      def find(id) = shares.with_code.by_pk(id).one
    end
  end
end
