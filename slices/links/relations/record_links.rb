# frozen_string_literal: true

module Links
  module Relations
    class RecordLinks < Blog::DB::Relation
      schema :record_links, infer: true

      def between(left_kind, left_id, right_kind, right_id) = where(left_kind:, left_id:, right_kind:, right_id:)

      def touching(kind, id)
        where(Sequel.|({ left_kind: kind, left_id: id }, { right_kind: kind, right_id: id }))
      end
    end
  end
end
