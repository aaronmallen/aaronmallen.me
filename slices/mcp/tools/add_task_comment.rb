# frozen_string_literal: true

module MCP
  module Tools
    class AddTaskComment < Base
      description "Add a comment to a task, as the admin's comment form does. It stays on this site and never " \
                  "posts to GitHub or Linear. The body comes back marked untrusted, as every comment body does. " \
                  "#{Untrusted::WARNING}"
      endpoint scope: OAuth::Scope::WRITE

      class << self
        private

        def answered(comment) = Untrusted.fields(comment, "body")
      end
    end
  end
end
