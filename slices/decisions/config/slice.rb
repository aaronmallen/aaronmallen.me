# frozen_string_literal: true

module Decisions
  class Slice < Hanami::Slice
    export %w[
      operations.add_decision_option operations.delete_decision_option operations.drop_decision
      operations.edit_decision operations.edit_decision_option operations.open_decision operations.reopen_decision
      operations.resolve_decision
    ]
  end
end
