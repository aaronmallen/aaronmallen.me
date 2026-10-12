# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class Attachments < Component
          prop :message, Blog::Types::Instance(ROM::Struct)

          def view_template
            files = @message.mail_attachments
            return if files.empty?

            ul(class: "mail-files", aria: { label: t(".label") }) { files.each { file(it) } }
          end

          private

          def file(attachment)
            li do
              a(class: "mail-file", href: path(:admin_mail_attachment, id: @message.id, part: attachment.part_id)) do
                Icon("fa-regular fa-file")
                plain attachment.filename
                span(class: "mail-dim") { Blog::Helpers::Figures.size(attachment.size) }
              end
            end
          end
        end
      end
    end
  end
end
