# frozen_string_literal: true

module Tasks
  module Relations
    class RecordLinks < Blog::DB::Relation
      DECISION = Blog::Types::RecordKind["decision"]
      SOURCED_FROM = Blog::Types::RecordLinkRelation["sourced_from"]
      TASK = Blog::Types::RecordKind["task"]

      schema :record_links, infer: true

      def source_from_decision(task_id, decision_id)
        link = { left_kind: TASK, left_id: task_id, right_kind: DECISION, right_id: decision_id }
        dataset.insert(**link, relation: SOURCED_FROM)
      end
    end
  end
end
