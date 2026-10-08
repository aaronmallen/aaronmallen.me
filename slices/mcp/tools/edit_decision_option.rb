# frozen_string_literal: true

module MCP
  module Tools
    class EditDecisionOption < Base
      description "Edit one option of a decision. A field you leave out keeps what it has. Editing an option of a " \
                  "resolved or dropped decision needs a note, which goes on its timeline"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
