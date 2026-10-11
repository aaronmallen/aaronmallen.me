# frozen_string_literal: true

module Shares
  module Repos
    class ShareQueries < Blog::DB::Repo
      IMAGES = Blog::Types::ShareFilter["images"]
      OTHER = Blog::Types::ShareFilter["other"]

      def by_code(code) = shares.with_code.where(Sequel[:short_codes][:code] => code).one

      def count_listed(**) = listed(**).count

      def find(id) = shares.with_code.by_pk(id).one

      def page_listed(page, **) = page.fill(listed(**).newest_first.paged(page).to_a)

      def totals = { count: shares.count, bytes: shares.sum(:byte_size).to_i }

      private

      def listed(filter:, search: nil)
        found = shares.with_code
        found = found.images if filter == IMAGES
        found = found.others if filter == OTHER
        search ? found.matching(search) : found
      end
    end
  end
end
