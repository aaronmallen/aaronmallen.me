# frozen_string_literal: true

module MCP
  module Tools
    class Search < Base
      READERS = {
        "task" => "read_task", "post" => "read_post", "social" => "read_social_post", "journal" => "read_journal_entry",
        "commit" => "read_commit", "project" => "read_project", "work" => "read_work_entry", "person" => "read_person",
        "message" => "read_mail_thread", "webmention" => "read_webmention", "decision" => "read_decision",
        "pull_request" => "read_pull_request",
      }.freeze

      description "Find records of every kind the admin keeps by their words, best match first, as the admin's " \
                  "search screen does: tasks open and closed, posts, social posts, journal entries, commits, " \
                  "projects, work entries, people, mail threads, webmentions, decisions and pull requests. A " \
                  "task label such as POD-23, or a bare 23, lists those tasks first. Each result gives its kind, " \
                  "id, title, a short match, its day and, for a task, its label; pass the id to the tool for its " \
                  "kind to read the whole record (#{READERS.map do |kind, tool|
                    "#{kind}: #{tool}"
                  end.join(', ')}). count gives the results on " \
                  "this page. #{API::Helpers::Paging::USAGE}. The match of a task, the title of a synced task, " \
                  "and the title and match of a commit, message, webmention or pull request, come marked " \
                  "untrusted. #{Untrusted::WARNING}"
      endpoint
    end
  end
end
