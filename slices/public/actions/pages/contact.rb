# frozen_string_literal: true

module Public
  module Actions
    module Pages
      class Contact < Action
        SENT = Blog::Constants::CHECKED

        before :forbid_caching

        def handle(request, response)
          response.render(view, sent: Blog::Types::Checkbox[request.params[:sent]])
        end
      end
    end
  end
end
