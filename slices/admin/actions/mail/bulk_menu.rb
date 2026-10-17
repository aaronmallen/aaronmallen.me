# frozen_string_literal: true

module Admin
  module Actions
    module Mail
      class BulkMenu < Action
        include Deps[thread_queries: "mail.repos.thread_queries"]

        def handle(request, response)
          ids = picked_ids(request)
          halt :not_found if ids.empty?

          list = Helpers::MailList.from(request.params)
          response.render(view, ids:, list:, fields: list, labels:, accounts:)
        end

        private

        def accounts = thread_queries.accounts.to_h { [it.id, it.name] }

        def labels = thread_queries.labels
      end
    end
  end
end
