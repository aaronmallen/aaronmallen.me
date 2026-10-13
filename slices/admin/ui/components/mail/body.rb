# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class Body < Component
          prop :message, Blog::Types::Instance(ROM::Struct)

          def view_template
            html = @message.html_body
            return p(class: "msg-body mail-message-body") { @message.body } if html.to_s.strip.empty?

            div(class: "mail-message-body mail-rich") { raw(safe(html)) }
          end
        end
      end
    end
  end
end
