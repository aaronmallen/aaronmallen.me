# frozen_string_literal: true

module Admin
  module Actions
    module Journal
      class Index < Action
        include Deps[summarize_journal: "operations.summarize_journal"]

        def handle(request, response)
          search = Blog::Types::Text[request.params[:q]]

          response.render(view, **summarize_journal.call(search:), search:)
        end
      end
    end
  end
end
