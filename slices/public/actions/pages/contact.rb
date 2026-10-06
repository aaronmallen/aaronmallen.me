# frozen_string_literal: true

module Public
  module Actions
    module Pages
      class Contact < Action
        SENT = Blog::Constants::CHECKED

        include Deps[issue_stamp: "operations.issue_contact_stamp"]

        before :forbid_caching

        def handle(request, response)
          response.render(
            view,
            sent: Blog::Types::Checkbox[request.params[:sent]],
            values: { UI::Views::Pages::Contact::STAMP => issue_stamp.call },
          )
        end
      end
    end
  end
end
