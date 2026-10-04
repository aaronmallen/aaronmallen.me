# frozen_string_literal: true

module MCP
  module Tools
    class LinkTasks < Base
      description "Link one task to another. A pair takes one link, whichever way it runs. " \
                  "The note and each comment's body may come from an issue tracker and come marked " \
                  "untrusted. #{Untrusted::WARNING}"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
