# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Mail
        class Settings < View
          FORM = Blog::Types::MailProvider["contact_form"]
          RULES = %i[contact_form people needs_reply starred important skip_notifications]
                  .to_h { [it, ".rules.#{it}"] }.freeze

          prop :accounts, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :settings, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::Bool)
          prop :waiting, Blog::Types::Integer

          def view_template
            content_for(:live_tables, Blog::Constants::EMPTY_ARRAY)
            PageHead(title: t(".heading"), sub: t(".sub")) do
              BackLink(href: path(:admin_mail), variant: :gh) { t(".back") }
            end
            AutoForm(method: "post", action: path(:admin_update_mail_settings)) do
              cards
              noscript { Button(type: "submit", small: true) { t(".save") } }
            end
          end

          private

          def account(account)
            form = account.provider == FORM

            div(class: "form-stack") do
              p { form ? t(".contact_form") : account.address }
              toggle(account, :shown, form ? ".show_form" : ".show")
              toggle(account, :sends, ".send") unless form
            end
          end

          def cards
            div(class: "g-main") do
              Card(title: t(".accounts"), id: "mail-accounts") { @accounts.each { account(it) } }
              Card(title: t(".waiting"), id: "mail-waiting") { rules }
            end
          end

          def rules
            Hint { t(".waiting_hint", count: @waiting) }
            div(class: "form-stack") do
              RULES.each do |rule, label_key|
                Checkbox(label: t(label_key), name: "settings[#{rule}]", checked: @settings.fetch(rule))
              end
            end
          end

          def toggle(account, name, label_key)
            Checkbox(
              switch: true, label: t(label_key), name: "accounts[#{account.id}][#{name}]",
              checked: account.public_send(name),
            )
          end
        end
      end
    end
  end
end
