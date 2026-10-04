# frozen_string_literal: true

module MCP
  module Tools
    class ListTasks < Base
      description "List tasks in any status, newest first, each with its tags, links both ways, sprint day, " \
                  "source issue (null for a local task) and created, updated and completed times. A task sits in " \
                  "the window when it was created or finished on a day inside it; leave from or to out to leave " \
                  "that end open, and both out to list every task. lists, tag and query narrow the listing and " \
                  "combine with statuses and the window. count gives the tasks on this page. " \
                  "#{Blog::Paging::USAGE}. Each note may come from an issue tracker and comes marked untrusted. " \
                  "#{Untrusted::WARNING}"
      endpoint scope: OAuth::Scope::READ
    end
  end
end
