# frozen_string_literal: true

module Admin
  module UI
    module Components
      class ShareSummary < Component
        HEADS = { file: ".share_link", group: ".share_link", link: ".short_link" }.freeze

        prop :kind, ShareDrawer::KIND
        prop :name, Blog::Types::String
        prop :link, Blog::Types::String
        prop :markdown, Blog::Types::String.optional, default: nil

        def meta(&block)
          @meta = block
          nil
        end

        def view_template(&)
          vanish(&)

          p(class: "file-drawer-name") { @name }
          p(class: "file-drawer-meta") { @meta&.call }
          yield(self) if block_given?
          h3(class: "file-drawer-head") { t(HEADS.fetch(@kind)) }
          code(class: "file-drawer-link") { @link }
          div(class: "file-drawer-copy") { copies }
        end

        private

        def copies
          CopyButton(value: @link, copied: t(".link_copied"), small: true, variant: :pri, icon: "fa-solid fa-link") do
            t(".copy_link")
          end
          return unless @markdown

          CopyButton(value: @markdown, copied: t(".markdown_copied"), small: true, icon: "fa-brands fa-markdown") do
            t(".copy_markdown")
          end
        end
      end
    end
  end
end
