# frozen_string_literal: true

module MCP
  module Tools
    class Search < Base
      READERS = {
        "task" => "read_task", "post" => "read_post", "social" => "read_social_post", "journal" => "read_journal_entry",
        "commit" => "read_commit", "project" => "read_project", "work" => "read_work_entry", "person" => "read_person",
        "message" => "read_message", "webmention" => "read_webmention",
      }.freeze
      MARKED = { "task" => %w[match], "message" => %w[title match], "webmention" => %w[title match] }.freeze

      description "Find records of every kind the admin keeps by their words, best match first, as the admin's " \
                  "search screen does: tasks open and closed, posts, social posts, journal entries, commits, " \
                  "projects, work entries, people, messages and webmentions. Each result gives its kind, id, " \
                  "title, a short match and its day; pass the id to the tool for its kind to read the whole record " \
                  "(#{READERS.map { |kind, tool| "#{kind}: #{tool}" }.join(', ')}). count gives the results on " \
                  "this page. #{Blog::Paging::USAGE}. The match of a task, and the title and match of a message or " \
                  "webmention, come marked untrusted. #{Untrusted::WARNING}"
      endpoint scope: OAuth::Scope::READ

      class << self
        private

        def answered(found) = found.merge(results: found.fetch(:results).map { marked_hit(it) })

        def marked_hit(hit) = Untrusted.fields(hit, *MARKED.fetch(hit.fetch("kind"), Blog::Constants::EMPTY_ARRAY))
      end
    end
  end
end
