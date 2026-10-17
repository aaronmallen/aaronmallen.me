# frozen_string_literal: true

module Shares
  module Repos
    class ShortLinkQueries < Blog::DB::Repo
      CLICKS = Blog::Types::ShortLinkSort["clicks"]

      def by_code(code) = short_links.with_code.where(Sequel[:short_codes][:code] => code).one

      def by_destination(destination)
        short_links.with_code.where(destination:).order(Sequel[:short_links][:id]).limit(1).one
      end

      def check(link) = checks([link])[link.id]

      def checks(links)
        destinations = links.to_h { [it.id, it.destination] }

        current = short_link_checks.where(short_link_id: destinations.keys).to_a
        current.select { destinations[it.short_link_id] == it.url }.to_h { [it.short_link_id, it] }
      end

      def count_listed(search: nil, failing: false) = listed(search, failing).count

      def destinations = short_links.select(:id, :destination).to_a

      def failing
        failing = short_links.with_check.exclude(Sequel[:short_link_checks][:reason] => nil)

        failing.order(Sequel[:short_link_checks][:failures].desc, Sequel[:short_links][:id]).to_a
      end

      def find(id) = short_links.with_code.by_pk(id).one

      def held_fetches = held_title_fetches.oldest_first.to_a

      def latest_to(destination) = short_links.with_code.where(destination:).newest_first.limit(1).one

      def page_listed(page, sort:, search: nil, failing: false)
        page.fill(ordered(listed(search, failing), sort, failing).paged(page).to_a)
      end

      def totals
        { count: short_links.count, clicks: short_links.sum(:click_count).to_i, failing: short_links.failing.count }
      end

      private

      def listed(search, failing)
        found = failing ? short_links.with_code.failing : short_links.with_code
        search ? found.matching(search) : found
      end

      def ordered(found, sort, failing)
        return found.longest_failing if failing

        sort == CLICKS ? found.most_clicked : found.newest_first
      end
    end
  end
end
