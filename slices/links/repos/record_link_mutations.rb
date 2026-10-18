# frozen_string_literal: true

module Links
  module Repos
    class RecordLinkMutations < Blog::DB::Repo
      KINDS = Blog::Types::RecordKind.values
      TASK_PROJECT = [Blog::Types::RecordKind["task"], Blog::Types::RecordKind["project"]].freeze

      root :record_links

      commands :create

      def implied?(*sides) = record_links.implied.between(*sorted(*sides).flatten).exist?

      def link(*sides)
        (left_kind, left_id), (right_kind, right_id) = sorted(*sides)

        create(left_kind:, left_id:, right_kind:, right_id:)
      end

      def sorted(*sides) = sides.sort_by { |kind, id| [KINDS.index(kind), id] }

      def task_project?(*sides) = sorted(*sides).map(&:first) == TASK_PROJECT

      def unlink(*sides) = record_links.between(*sorted(*sides).flatten).delete
    end
  end
end
