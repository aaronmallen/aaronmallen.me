# frozen_string_literal: true

module MCP
  module Tools
    class CreatePost < Base
      description "Write a new blog post as a draft. Nothing goes out until publish_post. " \
                  "The post takes the same checks the admin editor makes, and a refusal names each field at fault"
      endpoint
    end
  end
end
