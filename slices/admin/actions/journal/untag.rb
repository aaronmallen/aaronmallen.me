# frozen_string_literal: true

module Admin
  module Actions
    module Journal
      class Untag < TagAction
        DONE = "untagged"

        include Deps[untag_journal_entry: "record.operations.untag_journal_entry"]

        private

        def list_path = routes.path(:admin_journal)

        def retag(id, tag) = untag_journal_entry.call(id, tag)
      end
    end
  end
end
