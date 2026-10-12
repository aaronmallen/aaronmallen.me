# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class FolderSelect < Component
          ID = "mail-folder"

          prop :list, Blog::Types::Hash
          prop :counts, Blog::Types::Hash
          prop :labels, Blog::Types::Hash
          prop :chips, Blog::Types::Hash

          def view_template
            label(class: "sr-only", for: ID) { t(".label") }
            select(id: ID, name: "folder", class: "inp mail-folder-select") do
              optgroup(label: t(".folders")) { Blog::Types::MailFolder.each_value { folder(it) } }
              optgroup(label: t(".labels")) { @labels.each { |account, names| labels(account, names) } }
            end
          end

          private

          def folder(value)
            count = @counts.fetch(value, 0)
            name = t(Folders::NAMES.fetch(value))
            option(value, count.zero? ? name : "#{name} · #{count}")
          end

          def labels(account, names)
            names.each do |(name, _)|
              text = @list[:account] ? "##{name}" : "##{name} · #{@chips.fetch(account).first}"
              option("#{Helpers::MailList::LABEL}#{name}", text)
            end
          end

          def option(value, text) = super(value:, selected: value == @list[:folder]) { text }
        end
      end
    end
  end
end
