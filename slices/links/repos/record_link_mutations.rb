# frozen_string_literal: true

module Links
  module Repos
    class RecordLinkMutations < DB::Repo
      KINDS = Blog::Types::RecordKind.values

      root :record_links

      commands :create

      def link(*sides)
        (left_kind, left_id), (right_kind, right_id) = sorted(*sides)

        create(left_kind:, left_id:, right_kind:, right_id:)
      end

      def unlink(*sides) = record_links.between(*sorted(*sides).flatten).delete

      private

      def sorted(*sides) = sides.sort_by { |kind, id| [KINDS.index(kind), id] }
    end
  end
end
