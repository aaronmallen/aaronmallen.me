# frozen_string_literal: true

module MCP
  module Tools
    class EditTaskComment < Base
      description "Replace the body of one comment on a task. A comment synced from GitHub or Linear cannot be " \
                  "edited. The body comes back marked untrusted, as every comment body does. " \
                  "#{Untrusted::WARNING}"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
