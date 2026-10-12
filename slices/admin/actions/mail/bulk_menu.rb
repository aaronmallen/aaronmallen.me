# frozen_string_literal: true

module Admin
  module Actions
    module Mail
      class BulkMenu < Action
        include Deps[thread_queries: "mail.repos.thread_queries"]

        def handle(request, response)
          ids = picked_ids(request)
          halt 404 if ids.empty?

          list = Helpers::MailList.from(request.params)
          page = Blog::Types::PageParam.call(request.params[:page]) { 1 }
          response.render(view, ids:, list:, fields: { **list, **Blog::Structs::Page.query(page) }, labels:, accounts:)
        end

        private

        def accounts = thread_queries.accounts.to_h { [it.id, it.name] }

        def labels = thread_queries.labels
      end
    end
  end
end
