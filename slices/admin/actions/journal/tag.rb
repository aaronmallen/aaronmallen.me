# frozen_string_literal: true

module Admin
  module Actions
    module Journal
      class Tag < TagAction
        DONE = "tagged"

        include Deps[tag_journal_entry: "record.operations.tag_journal_entry"]

        private

        def list_path = routes.path(:admin_journal)

        def retag(id, tag) = tag_journal_entry.call(id, tag)
      end
    end
  end
end
