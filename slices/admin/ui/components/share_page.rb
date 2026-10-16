# frozen_string_literal: true

module Admin
  module UI
    module Components
      class SharePage < Component
        prop :back, Blog::Types::String
        prop :back_label, Blog::Types::String
        prop :title, Blog::Types::String
        prop :form, Blog::Types::Class
        prop :record, Blog::Types::Instance(ROM::Struct)
        prop :kind, ShareDrawer::KIND

        def view_template
          BackLink(href: @back, variant: :gh, small: true, class: "editor-back") { @back_label }
          PageHead(title: @title)
          Card(class: "file-drawer") do
            yield
            div(class: "file-drawer-foot") { ShareFoot(form: @form, record: @record, kind: @kind) }
          end
        end
      end
    end
  end
end
