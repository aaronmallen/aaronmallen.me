# frozen_string_literal: true

module MCP
  module Tools
    class ReorderTask < Base
      description "Move one open task a place up or down among the open tasks in its list or sprint. " \
                  "At either end, or once done or canceled, it stays put and moved comes back false. " \
                  "The note and each comment's body may come from an issue tracker and come marked " \
                  "untrusted. #{Untrusted::WARNING}"
      endpoint scope: OAuth::Scope::WRITE

      class << self
        private

        def answered(task) = Untrusted.task(task)
      end
    end
  end
end
