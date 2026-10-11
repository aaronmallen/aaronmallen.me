# frozen_string_literal: true

module Shares
  module Repos
    class ShortLinkQueries < Blog::DB::Repo
      CLICKS = Blog::Types::ShortLinkSort["clicks"]

      def by_code(code) = short_links.with_code.where(Sequel[:short_codes][:code] => code).one

      def count_listed(search: nil) = listed(search).count

      def find(id) = short_links.with_code.by_pk(id).one

      def latest_to(destination) = short_links.with_code.where(destination:).newest_first.limit(1).one

      def page_listed(page, sort:, search: nil)
        found = listed(search)
        page.fill((sort == CLICKS ? found.most_clicked : found.newest_first).paged(page).to_a)
      end

      def totals = { count: short_links.count, clicks: short_links.sum(:click_count).to_i }

      private

      def listed(search) = search ? short_links.with_code.matching(search) : short_links.with_code
    end
  end
end
