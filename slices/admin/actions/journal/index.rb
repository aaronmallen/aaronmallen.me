# frozen_string_literal: true

module Admin
  module Actions
    module Journal
      class Index < Action
        include Deps[summarize_journal: "operations.summarize_journal"]

        def handle(request, response)
          search = Blog::Types::Text[request.params[:q]]
          to = Blog::Types::DateParam[request.params[:to]]
          writing = Blog::Types::Checkbox[request.params[:write]]

          response.render(view, **summarize_journal.call(search:, to:), search:, writing:)
        end
      end
    end
  end
end
