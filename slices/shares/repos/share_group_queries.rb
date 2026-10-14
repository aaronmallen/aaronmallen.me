# frozen_string_literal: true

module Shares
  module Repos
    class ShareGroupQueries < Blog::DB::Repo
      def by_code(code)
        share_groups.with_code.where(Sequel[:short_codes][:code] => code)
                    .combine(:share_group_files).node(:share_group_files) { it.order(:id) }.one
      end

      def count = share_groups.count

      def find(id) = share_groups.with_code.by_pk(id).combine(:share_group_files).one

      def page(page) = page.fill(share_groups.with_code.newest_first.paged(page).combine(:share_group_files).to_a)
    end
  end
end
