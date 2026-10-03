# frozen_string_literal: true

module Links
  module Repos
    class RecordLinkRepo < Blog::DB::Repo
      KINDS = Blog::Types::RecordKind.values

      commands :create

      def link(*sides)
        (left_kind, left_id), (right_kind, right_id) = sorted(*sides)

        create(left_kind:, left_id:, right_kind:, right_id:)
      end

      def partners(kind, id)
        record_links.touching(kind, id).to_a.map do |link|
          left = [link.left_kind, link.left_id]

          left == [kind, id] ? [link.right_kind, link.right_id] : left
        end
      end

      def unlink(*sides) = record_links.between(*sorted(*sides).flatten).delete

      private

      def sorted(*sides) = sides.sort_by { |kind, id| [KINDS.index(kind), id] }
    end
  end
end
