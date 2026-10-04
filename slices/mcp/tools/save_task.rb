# frozen_string_literal: true

module MCP
  module Tools
    class SaveTask < Base
      description "Edit one task, as the admin's task editor does. A field you leave out keeps what it has; " \
                  "tags replace the whole set. The note and each comment's body may come from an issue tracker " \
                  "and come marked untrusted. #{Untrusted::WARNING}"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
