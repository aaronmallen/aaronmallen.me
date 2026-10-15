# auto_register: false
# frozen_string_literal: true

module Admin
  module Actions
    module Mail
      module Redirect
        private

        def listed(request, **)
          list = Helpers::MailList.from(request.params)
          page = landing(request) { thread_queries.page_listed(it, **Helpers::MailList.query(list)).past_end? }

          Helpers::MailList.back(routes, list, **Blog::Structs::Page.query(page), **)
        end
      end
    end
  end
end
