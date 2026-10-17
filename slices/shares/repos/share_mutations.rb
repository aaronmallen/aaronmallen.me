# frozen_string_literal: true

module Shares
  module Repos
    class ShareMutations < Blog::DB::Repo
      include CodedMutations

      root :shares

      stamped_commands :update

      def count_download(id) = shares.by_pk(id).update(download_count: Sequel[:download_count] + 1)
    end
  end
end
