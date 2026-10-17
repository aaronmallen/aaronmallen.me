# frozen_string_literal: true

module Shares
  module Relations
    class ShortLinks < Blog::DB::Relation
      CHECK = %i[reason failures checked_at first_failed_at].freeze

      use :short_coded

      schema :short_links, infer: true do
        associations do
          belongs_to :short_code
        end
      end

      def failing
        checks = Sequel[:short_link_checks]

        join(:short_link_checks, { short_link_id: Sequel[:short_links][:id], url: Sequel[:short_links][:destination] })
          .exclude(checks[:reason] => nil)
      end

      def longest_failing = order(Sequel[:short_link_checks][:failures].desc, *newest)

      def matching(text) = containing(text, self[:title], self[:destination], Sequel[:short_codes][:code])

      def most_clicked = order(self[:click_count].desc, *newest)

      def newest_first = order(*newest)

      def with_check
        on = { short_link_id: self[:id].qualified, url: self[:destination].qualified }
        joined = with_code.join(:short_link_checks, on)
        joined.select_append { |short_link_checks:| CHECK.map { short_link_checks[it] } }
      end

      private

      def newest = [self[:created_at].desc, self[:id].desc]
    end
  end
end
