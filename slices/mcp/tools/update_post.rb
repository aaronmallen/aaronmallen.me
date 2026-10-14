# frozen_string_literal: true

module MCP
  module Tools
    class UpdatePost < Base
      description "Change one blog post: its body or any other field. A field you leave out keeps what it has. " \
                  "A draft stays a draft and a scheduled post stays scheduled, at its new publish time if you " \
                  "give one, which has to be still to come. A scheduled post whose time has passed needs a new " \
                  "one. A published post keeps its slug and its publish time, and a change to its body needs " \
                  "an edit_note saying what changed and why. " \
                  "The post takes the same checks the admin editor makes, and a refusal names each field at fault"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
