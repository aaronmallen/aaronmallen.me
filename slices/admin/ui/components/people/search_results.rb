# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class SearchResults < Component
          AVATAR_SIZE = 32
          BLUESKY = Blog::Types::NetworkName["bluesky"]
          PROBLEMS = { failed: ".failed", rate_limited: ".rate_limited" }.freeze
          SECURE = "https://"

          prop :network, Blog::Types::NetworkName
          prop :accounts, Blog::Types::Array.of(Blog::Types::Instance(::Social::Structs::Account)), default: -> { Blog::Constants::EMPTY_ARRAY }
          prop :problem, Blog::Types::Symbol.optional, default: nil

          def view_template
            return Hint(class: "bad", data: { person_finder_note: @problem.name }) { problem } if @problem
            return Empty { t(".none") } if @accounts.empty?

            Hint(data: { person_finder_count: "" }) { t(".found", count: @accounts.size) }
            @accounts.each { result(it) }
          end

          private

          def add_button(account)
            Button(
              small: true, aria: { label: t(".add_label", name: name(account)) },
              data: { person_add: account.handle, person_add_name: account.name, person_add_network: @network },
            ) { t(".add") }
          end

          def avatar(account)
            return span(class: "person-result-avatar", aria: { hidden: "true" }) unless secure?(account.avatar)

            img(
              class: "person-result-avatar", src: account.avatar, alt: "", width: AVATAR_SIZE, height: AVATAR_SIZE,
              loading: "lazy", referrerpolicy: "no-referrer",
            )
          end

          def body(account)
            div(class: "person-result-body") do
              p(class: "person-result-name") { name(account) }
              p(class: "person-result-handle #{@network}") do
                Icon(Blog::Constants::NETWORK_ICONS.fetch(@network))
                plain handle(account)
              end
            end
          end

          def handle(account) = @network == BLUESKY ? "@#{account.handle}" : account.handle

          def name(account) = account.name.empty? ? account.handle : account.name

          def problem = t(PROBLEMS.fetch(@problem), network: t(Structs::Network::LABELS.fetch(@network)))

          def result(account)
            div(class: "person-result", data: { person_result: "" }) do
              avatar(account)
              body(account)
              add_button(account)
            end
          end

          def secure?(url) = url.to_s.start_with?(SECURE)
        end
      end
    end
  end
end
