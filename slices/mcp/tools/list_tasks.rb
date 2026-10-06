# frozen_string_literal: true

module MCP
  module Tools
    class ListTasks < Base
      description "List tasks in any status, newest first, each with its tags, links both ways, sprint day, " \
                  "source issue (null for a local task) and created, updated and completed times. A task sits in " \
                  "the window when it was created or finished on a day inside it; leave from or to out to leave " \
                  "that end open, and both out to list every task. lists, tag and query narrow the listing and " \
                  "combine with statuses and the window. sprint_on keeps the tasks planned into that day's sprint. " \
                  "count gives the tasks on this page and total the tasks that match across every page. " \
                  "#{Blog::Paging::USAGE}. #{Untrusted::TASKS}"
      endpoint scope: OAuth::Scope::READ
    end
  end
end
