# frozen_string_literal: true

module Shares
  module Relations
    class Shares < Blog::DB::Relation
      IMAGE = "image/%"

      use :short_coded

      schema :share_group_files, as: :shares, infer: true do
        associations do
          belongs_to :short_code
        end
      end

      dataset do |relation|
        columns = relation.schema
        coded = select(*columns.qualified_projection).exclude(columns[:short_code_id].qualified => nil)
        coded.order(columns[:id].qualified)
      end

      def images = where(Sequel.like(self[:content_type], IMAGE))

      def matching(text) = containing(text, self[:filename], self[:content_type], Sequel[:short_codes][:code])

      def others = exclude(Sequel.like(self[:content_type], IMAGE))
    end
  end
end
