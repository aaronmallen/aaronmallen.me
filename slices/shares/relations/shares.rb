# frozen_string_literal: true

module Shares
  module Relations
    class Shares < Blog::DB::Relation
      IMAGE = "image/%"

      schema :shares, infer: true do
        associations do
          belongs_to :short_code
        end
      end

      def images = where(Sequel.like(self[:content_type], IMAGE))

      def matching(text) = containing(text, self[:filename], self[:content_type], Sequel[:short_codes][:code])

      def newest_first = order(self[:created_at].desc, self[:id].desc)

      def others = exclude(Sequel.like(self[:content_type], IMAGE))

      def with_code = qualified.join(:short_codes).select_append { |short_codes:| short_codes[:code] }
    end
  end
end
