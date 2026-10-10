# frozen_string_literal: true

module MCP
  module Tools
    class ListAttention < Base
      NEW_DEVICE = Blog::Types::AttentionKind["new_device"]
      TITLE = "title"

      description "List the rows the admin's needs attention card shows, worst first: a sign-in, API token or MCP " \
                  "client seen from a device or place it had not used before, with days since; open tasks carried " \
                  "too many days, with carried_count; drafts and someday tasks left alone too long, with days " \
                  "since the last edit; and the journal, with days since the last entry. Snoozed rows stay out. " \
                  "Beside them, dead_jobs lists the background jobs that ran out of retries, newest first, with " \
                  "the job's name, when it died and its error. " \
                  "A new device row's title names an MCP client as the client named itself, so it comes marked " \
                  "untrusted, and so does the title of a carried or someday task that syncs from an issue " \
                  "tracker. #{Untrusted::WARNING}"
      endpoint scope: Blog::Types::OAuthScope["read"]

      class << self
        private

        def answered(found) = super(found.merge(attention: found.fetch(:attention).map { marked(it) }))

        def marked(row) = row.fetch("kind") == NEW_DEVICE ? Untrusted.fields(row, TITLE) : row
      end
    end
  end
end
