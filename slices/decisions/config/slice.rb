# frozen_string_literal: true

module Decisions
  class Slice < Hanami::Slice
    import keys: %w[operations.claim_photos operations.release_photos], from: :media

    export %w[
      operations.add_decision_comment operations.add_decision_option operations.delete_decision_comment
      operations.delete_decision_option operations.drop_decision operations.edit_decision
      operations.edit_decision_comment operations.edit_decision_option operations.open_decision
      operations.reopen_decision operations.resolve_decision queries.by_id queries.by_status queries.by_tag
      queries.comments queries.count_by_status queries.find_decisions queries.found_decision_counts
      queries.linkable_decisions queries.timeline
    ]
  end
end
