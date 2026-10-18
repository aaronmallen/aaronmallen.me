# frozen_string_literal: true

module MCP
  module Tools
    class ReadTag < Base
      description "Read each scope's description of one tag name and what carries it, the way the admin's tag " \
                  "page shows it: how many posts and projects have the public tag and how many tasks, journal " \
                  "entries and decisions have the private one, with a page of each kind. Drafts, archived " \
                  "projects and closed tasks come too, each with its status. Rows are short: read_task and the " \
                  "other read tools give the whole record. Each kind pages on its own: when one comes back " \
                  "partial, send its kind and its next_page as page for the rest. A name neither scope holds " \
                  "is refused. Each synced task's title may come from an issue tracker and comes marked untrusted. " \
                  "#{Untrusted::WARNING}"
      endpoint
    end
  end
end
