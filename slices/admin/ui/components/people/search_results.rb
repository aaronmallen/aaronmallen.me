# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class SearchResults < Component
          AVATAR_SIZE = 32
          PROBLEMS = { failed: ".failed", rate_limited: ".rate_limited" }.freeze
          SECURE = "https://"

          prop :network, Blog::Types::NetworkName
          prop :accounts, Blog::Types::Array.of(Blog::Types::Instance(::Social::Structs::Account)), default: -> { Blog::Constants::EMPTY_ARRAY }
          prop :problem, Blog::Types::Symbol.optional, default: nil

          def view_template
            return note(t(PROBLEMS.fetch(@problem), network: network_label), @problem) if @problem
            return note(t(".none"), :none) if @accounts.empty?

            @accounts.each_with_index { |account, index| result(account, index) }
          end

          private

          def avatar(account)
            return span(class: "person-search-avatar", aria: { hidden: "true" }) unless secure?(account.avatar)

            img(
              class: "person-search-avatar", src: account.avatar, alt: "", width: AVATAR_SIZE, height: AVATAR_SIZE,
              loading: "lazy", referrerpolicy: "no-referrer",
            )
          end

          def network_label = t(Structs::Network::LABELS.fetch(@network))

          def note(text, kind)
            div(
              id: "#{Search.list_id(@network)}-#{kind}", class: "person-search-result person-search-note",
              role: "option", aria: { disabled: "true", selected: "false" }, data: { person_search_note: kind },
            ) { text }
          end

          def result(account, index)
            div(
              id: "#{Search.list_id(@network)}-#{index}", class: "person-search-result", role: "option",
              aria: { selected: "false" }, data: { person_pick: account.handle, person_pick_name: account.name },
            ) do
              avatar(account)
              span(class: "person-search-name") { account.name.empty? ? account.handle : account.name }
              span(class: "person-search-handle") { account.handle }
            end
          end

          def secure?(url) = url.to_s.start_with?(SECURE)
        end
      end
    end
  end
end
