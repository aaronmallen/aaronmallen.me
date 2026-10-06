# frozen_string_literal: true

module Public
  module Actions
    module Pages
      class Contact < Action
        SENT = Blog::Constants::CHECKED

        include Deps["contact_stamp"]

        before :forbid_caching

        def handle(request, response)
          response.render(
            view,
            sent: Blog::Types::Checkbox[request.params[:sent]],
            values: { ContactStamp::FIELD => contact_stamp.issue },
          )
        end
      end
    end
  end
end
