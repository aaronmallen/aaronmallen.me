# frozen_string_literal: true

module MCP
  module Tools
    class Search < Base
      description "Find records of every kind the admin keeps by their words, best match first, as the admin's " \
                  "search screen does: tasks open and closed, posts, social posts, journal entries, commits, " \
                  "projects, work entries, people, messages and webmentions. Each result gives its kind, id, " \
                  "title, a short match and its day; pass the id to read_task, read_post, read_social_post, " \
                  "read_journal_entry or read_message for the whole record. count gives the results on this " \
                  "page. #{Paging::USAGE}"
      input_schema(API::Endpoints::Search::SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, **input) = hand_over(:search, input, server_context)
      end
    end
  end
end
