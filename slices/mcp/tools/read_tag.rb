# frozen_string_literal: true

module MCP
  module Tools
    class ReadTag < Base
      description "Read each scope's description of one tag name and what carries it, the way the admin's tag " \
                  "page shows it: how many posts and projects have the public tag and how many tasks, journal " \
                  "entries, decisions, agent sessions, memory files and artifacts have the private one, with a " \
                  "page of each kind; the agent kinds come only with the agents permission. Drafts, archived " \
                  "projects and closed tasks come too, each with its status. Rows are short: read_task and the " \
                  "other read tools give the whole record. Each kind pages on its own: when one comes back " \
                  "partial, send its kind and its next_page as page for the rest. Give a project's key in project " \
                  "to read that project's own tag of the name instead, with what carries it but no projects, and " \
                  "with its notes and mail threads when this connection holds those scopes. A name neither scope " \
                  "holds, or the project lacks, is refused. Each synced task's title, each mail subject, each " \
                  "session's title and each title an agent set on an artifact may come from someone else and " \
                  "comes marked untrusted. #{Untrusted::WARNING}"
      endpoint
    end
  end
end
