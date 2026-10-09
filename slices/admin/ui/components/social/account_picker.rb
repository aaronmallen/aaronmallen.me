# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Social
        class AccountPicker < Component
          PICKED = /%\{picked\}/
          TOTAL = /%\{total\}/

          prop :accounts, Blog::Types::Array.of(Blog::Types::Instance(Structs::SocialAccount))
          prop :name, Blog::Types::String
          prop :errors, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }

          def view_template
            div(class: "compose-to") do
              span(class: "compose-to-label") { t(".to") }
              details(class: "compose-accounts") do
                toggle
                menu
              end
            end
            FieldError(field: :targets, errors: @errors)
          end

          private

          def account(account)
            label(class: "compose-account") do
              input(
                type: "checkbox", name: @name, value: account.id, checked: account.selected,
                data: { social_target: account.network },
              )
              span(class: "compose-account-handle") { account.handle }
              span(class: "compose-account-host") { account.host } if account.host
            end
          end

          def group(network, accounts)
            label = accounts.first.network_label
            div(class: ["compose-account-group", network], role: "group", aria: { label: }) do
              div(class: "compose-account-group-head") do
                IconLabel(icon: QueueItem::NETWORK_ICONS.fetch(network)) { label }
              end
              accounts.each { account(it) }
            end
          end

          def menu
            div(class: "compose-accounts-menu", role: "group", aria: { label: t(".menu") }) do
              @accounts.group_by(&:network).each { group(*it) }
              div(class: "compose-accounts-foot") { a(href: path(:admin_services)) { t(".manage") } }
            end
          end

          def template = t(".picked").sub(TOTAL, @accounts.size.to_s)

          def toggle
            summary(class: "bt sm gh compose-accounts-toggle") do
              span(data: { social_picked: "", template: }) { template.sub(PICKED, @accounts.count(&:selected).to_s) }
              Icon("fa-solid fa-chevron-down")
            end
          end
        end
      end
    end
  end
end
