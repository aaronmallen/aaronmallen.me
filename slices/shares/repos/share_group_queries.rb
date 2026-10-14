# frozen_string_literal: true

module Shares
  module Repos
    class ShareGroupQueries < Blog::DB::Repo
      IMAGES = Blog::Types::ShareFilter["images"]
      OTHER = Blog::Types::ShareFilter["other"]

      def by_code(code)
        share_groups.with_code.where(Sequel[:short_codes][:code] => code)
                    .combine(:share_group_files).node(:share_group_files) { it.order(:id) }.one
      end

      def count = share_groups.count

      def find(id)
        share_groups.with_code.by_pk(id).combine(:share_group_files).node(:share_group_files) { it.order(:id) }.one
      end

      def listed(filter:, search: nil)
        files = share_group_files
        files = files.images if filter == IMAGES
        files = files.others if filter == OTHER
        found = share_groups.with_code.where(Sequel[:share_groups][:id] => owners(files, search))
        found.newest_first.combine(:share_group_files).node(:share_group_files) { it.order(:id) }.to_a
      end

      def page(page) = page.fill(share_groups.with_code.newest_first.paged(page).combine(:share_group_files).to_a)

      private

      def owners(files, search)
        files = files.matching(search, Sequel[:short_codes][:code]) if search
        joined = files.join(:share_groups, id: :share_group_id).join(:short_codes, id: :short_code_id)
        joined.dataset.select(Sequel[:share_group_files][:share_group_id])
      end
    end
  end
end
