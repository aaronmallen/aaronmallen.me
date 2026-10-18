# frozen_string_literal: true

module Admin
  module Actions
    module Today
      class Show < Action
        include Deps[summarize_today: "operations.summarize_today"]

        def handle(request, response)
          case summarize(request)
            in Success(summary) then response.render(view, **summary)
          end
        end

        private

        def first_page = Blog::Structs::Page.new(number: 1, size: page_size)

        def summarize(request)
          inbox = navigation(request).inbox_count

          summarize_today.call(page: first_page, inbox:, pool: request.params[:pool])
        end
      end
    end
  end
end
