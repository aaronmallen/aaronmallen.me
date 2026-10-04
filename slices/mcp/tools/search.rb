# frozen_string_literal: true

module MCP
  module Tools
    class Search < Base
      MARKED = { "task" => %w[match], "message" => %w[title match], "webmention" => %w[title match] }.freeze

      description "Find records of every kind the admin keeps by their words, best match first, as the admin's " \
                  "search screen does: tasks open and closed, posts, social posts, journal entries, commits, " \
                  "projects, work entries, people, messages and webmentions. Each result gives its kind, id, " \
                  "title, a short match and its day; pass the id to read_task, read_post, read_social_post, " \
                  "read_journal_entry, read_commit, read_project, read_work_entry, read_message, read_person or " \
                  "read_webmention for the whole record. count gives the results on this page. " \
                  "#{Blog::Paging::USAGE}. The match of a task, and the title and match of a message or " \
                  "webmention, come marked untrusted. #{Untrusted::WARNING}"
      input_schema(API::Endpoints::Search::SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, **input) = hand_over(:search, input, server_context) { marked(it) }

        private

        def marked(found) = found.merge(results: found.fetch(:results).map { marked_hit(it) })

        def marked_hit(hit) = Untrusted.fields(hit, *MARKED.fetch(hit.fetch("kind"), Blog::Constants::EMPTY_ARRAY))
      end
    end
  end
end
