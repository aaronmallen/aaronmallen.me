# frozen_string_literal: true

module Links
  module Operations
    class UnlinkRecords < Blog::Operation
      include Deps[record_link_mutations: "repos.record_link_mutations"]

      def call(kind, id, other_kind, other_id)
        sides = step sides([kind, id], [other_kind, other_id])

        step affected(record_link_mutations.unlink(*sides))
      end

      private

      def side(kind, id)
        id = Blog::Types::IdParam[id]

        [kind, id] if id
      end

      def sides(*pairs)
        known = pairs.map { side(*it) }

        found(known.all? && known)
      end
    end
  end
end
