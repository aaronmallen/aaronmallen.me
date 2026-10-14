# frozen_string_literal: true

module Shares
  module Relations
    class ShareGroupFiles < Blog::DB::Relation
      schema :share_group_files, infer: true do
        associations do
          belongs_to :share_group
        end
      end

      def images = where(Sequel.like(self[:content_type], Relations::Shares::IMAGE))

      def matching(text, code) = containing(text, self[:filename], self[:content_type], code)

      def others = exclude(Sequel.like(self[:content_type], Relations::Shares::IMAGE))
    end
  end
end
