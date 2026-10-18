# frozen_string_literal: true

module MCP
  module Tools
    class ListAttention < Base
      description "List the rows the admin's needs attention card shows, worst first: a sign-in, API token or MCP " \
                  "client seen from a device or place it had not used before, with days since; links in published " \
                  "posts that failed the weekly check twice or more in a row, with the post's title and post_id, " \
                  "the url, the reason and failures; open tasks carried too many days, with carried_count; " \
                  "drafts and someday tasks left alone too long, with days since the last edit; a service " \
                  "connection that lapses within a week, titled with its account and with days left, below zero " \
                  "once it has lapsed; and the journal, with days since the last entry. Snoozed rows stay out. " \
                  "attention holds the worst five rows of each kind, and attention_counts gives every kind's " \
                  "total, zero for a kind with no rows, so a total above five counts rows the reply leaves out. " \
                  "Beside them, dead_jobs lists the newest five background jobs that ran out of retries, newest " \
                  "first, with the job's name, when it died and its error, and dead_job_count counts them all. " \
                  "A new device row's title names an MCP client as the client named itself, so it comes marked " \
                  "untrusted, and so does the title of a carried or someday task that syncs from an issue " \
                  "tracker. A dead job's error may quote what a remote service answered, so it comes marked " \
                  "untrusted too. #{Untrusted::WARNING}"
      endpoint
    end
  end
end
