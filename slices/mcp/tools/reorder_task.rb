# frozen_string_literal: true

module MCP
  module Tools
    class ReorderTask < Base
      description "Move one open task among the open tasks in its list or sprint, as the admin's drag does. " \
                  "Give direction to move it a place up or down, or after_id to put it right after that task; " \
                  "a null after_id puts it first. Each task's position gives the order. " \
                  "At either end, or when it or the after_id task is done or canceled, it stays put " \
                  "and moved comes back false. " \
                  "#{Untrusted::TASK}"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
