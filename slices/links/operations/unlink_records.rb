# frozen_string_literal: true

module Links
  module Operations
    class UnlinkRecords < Blog::Operation
      include Deps[record_link_repo: "repos.record_link_repo"]

      def call(kind, id, other_kind, other_id)
        sides = step sides([kind, id], [other_kind, other_id])

        step removed(record_link_repo.unlink(*sides))
      end

      private

      def removed(count) = count.positive? ? Success(count) : Failure(:not_found)

      def side(kind, id)
        id = Blog::Types::IdParam[id]

        [kind, id] if id && Blog::Types::RecordKind.valid?(kind)
      end

      def sides(*pairs)
        found = pairs.map { side(*it) }

        found.all? ? Success(found) : Failure(:not_found)
      end
    end
  end
end
