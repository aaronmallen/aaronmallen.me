# frozen_string_literal: true

module Admin
  module Actions
    module People
      class New < Action
        include Deps[
          build_person_editor: "operations.build_person_editor",
          mention_view: "ui.views.people.new_mention",
          person_queries: "contacts.repos.person_queries",
        ]

        def handle(request, response)
          return response.render(mention_view, **build_person_editor.call) if Create.mention?(request)

          values = Helpers::ContactForm.read(request.params[:person])
          values = Helpers::ContactForm.prefill(values, name: request.params[:name], email: request.params[:email])
          response.render(view, values:, errors: Blog::Constants::EMPTY_HASH, labels: person_queries.labels)
        end
      end
    end
  end
end
