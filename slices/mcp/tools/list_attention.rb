# frozen_string_literal: true

module MCP
  module Tools
    class ListAttention < Base
      description "List the stalled work the admin's needs attention card shows, worst first: open tasks carried " \
                  "too many days, with carried_count; drafts and someday tasks left alone too long, with days " \
                  "since the last edit; and the journal, with days since the last entry. Snoozed rows stay out"
      input_schema(API::Endpoints::ListAttention::SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, **input) = hand_over(:list_attention, input, server_context)
      end
    end
  end
end
