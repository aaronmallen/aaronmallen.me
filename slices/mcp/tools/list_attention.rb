# frozen_string_literal: true

module MCP
  module Tools
    class ListAttention < Base
      description "List the stalled work the admin's needs attention card shows, worst first: open tasks carried " \
                  "too many days, with carried_count; drafts and someday tasks left alone too long, with days " \
                  "since the last edit; and the journal, with days since the last entry. Snoozed rows stay out. " \
                  "The title of a carried or someday task that syncs from an issue may come from an issue " \
                  "tracker and comes marked untrusted. #{Untrusted::WARNING}"
      endpoint scope: OAuth::Scope::READ
    end
  end
end
