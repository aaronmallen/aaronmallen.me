# frozen_string_literal: true

module Admin
  module Actions
    module People
      class New < Action
        include Deps[build_person_editor: "operations.build_person_editor"]

        def handle(request, response)
          sender = { name: request.params[:name], emails: [{ value: request.params[:email] }] }

          response.render(view, **build_person_editor.call(params: sender))
        end
      end
    end
  end
end
