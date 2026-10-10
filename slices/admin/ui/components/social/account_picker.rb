# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Social
        class AccountPicker < Component
          SEARCH_AFTER = 5
          PICKED = /%\{picked\}/
          TOTAL = /%\{total\}/

          prop :accounts, Blog::Types::Array.of(Blog::Types::Instance(Structs::SocialAccount))
          prop :name, Blog::Types::String
          prop :errors, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }

          def view_template
            div(class: "compose-to", data: { social_picker: "" }) do
              span(class: "compose-to-label") { t(".to") }
              chips
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

          def chip(account)
            span(
              class: ["compose-chip", account.network], title: account.label, hidden: true,
              data: { social_chip: account.id, handle: account.handle },
            ) do
              Icon(QueueItem::NETWORK_ICONS.fetch(account.network))
              span(class: "compose-chip-handle") { account.handle }
              span(class: "compose-chip-host", hidden: true) { account.host } if account.host
              remove(account)
            end
          end

          def chips
            div(class: "compose-chips") do
              span(class: "compose-chips-empty", hidden: true, data: { social_empty: "" }) { t(".empty") }
              @accounts.each { chip(it) }
              button(
                type: "button", class: "compose-chips-more", hidden: true,
                data: { social_more: "", template: t(".more") },
              )
            end
          end

          def foot
            div(class: "compose-accounts-foot") do
              a(href: path(:admin_services)) { t(".manage") }
              button(type: "button", class: "compose-accounts-link", hidden: true, data: { social_everywhere: "" }) do
                t(".everywhere")
              end
              button(type: "button", class: "compose-accounts-link", hidden: true, data: { social_clear: "" }) do
                t(".clear")
              end
            end
          end

          def group(network, accounts)
            label = accounts.first.network_label
            div(class: ["compose-account-group", network], role: "group", aria: { label: }) do
              div(class: "compose-account-group-head") do
                IconLabel(icon: QueueItem::NETWORK_ICONS.fetch(network)) { label }
                group_link
              end
              accounts.each { account(it) }
            end
          end

          def group_link
            button(
              type: "button", class: "compose-accounts-link", hidden: true,
              data: { social_group: "", all: t(".all"), none: t(".none") },
            )
          end

          def menu
            div(class: "compose-accounts-menu", role: "group", aria: { label: t(".menu") }) do
              search
              @accounts.group_by(&:network).each { group(*it) }
              p(class: "compose-accounts-none", hidden: true, data: { social_none: "", template: t(".no_match") })
              foot
            end
          end

          def remove(account)
            label = t(".remove", account: account.label)
            button(type: "button", class: "compose-chip-remove", aria: { label: }) { Icon("fa-solid fa-xmark") }
          end

          def search
            return if @accounts.size <= SEARCH_AFTER

            input(
              type: "search", class: "inp compose-accounts-find", hidden: true, placeholder: t(".find"),
              aria: { label: t(".find") }, data: { social_find: "" },
            )
          end

          def template = t(".picked").sub(TOTAL, @accounts.size.to_s)

          def toggle
            summary(class: "bt sm gh") do
              span(data: { social_picked: "", template: }) { template.sub(PICKED, @accounts.count(&:selected).to_s) }
              Icon("fa-solid fa-chevron-down")
            end
          end
        end
      end
    end
  end
end
