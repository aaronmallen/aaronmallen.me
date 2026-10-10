# frozen_string_literal: true

module Decisions
  class Slice < Hanami::Slice
    import keys: %w[operations.claim_photos operations.release_photos], from: :media

    export %w[
      operations.add_decision_comment operations.add_decision_option operations.delete_decision_comment
      operations.delete_decision_option operations.drop_decision operations.edit_decision
      operations.edit_decision_comment operations.edit_decision_option operations.open_decision
      operations.reopen_decision operations.resolve_decision repos.decision_queries
    ]
  end
end
