# frozen_string_literal: true

module MCP
  module Tools
    class ReadTag < Base
      description "Read everything that carries one tag name, the way the admin's tag page shows it: the posts and " \
                  "projects with the public tag and the tasks, journal entries and decisions with the private " \
                  "one, grouped by kind, each with its status, drafts, archived projects and closed tasks " \
                  "among them. A name neither scope holds is refused. #{Untrusted::TASKS}"
      endpoint scope: Blog::Types::OAuthScope["read"]
    end
  end
end
