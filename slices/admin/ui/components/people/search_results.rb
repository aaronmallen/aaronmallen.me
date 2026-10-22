# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class SearchResults < Component
          AVATAR_SIZE = 32
          BLUESKY = Blog::Types::NetworkName["bluesky"]
          HANDLES = { "bluesky" => "bluesky_handle", "mastodon" => "mastodon_handle" }.freeze
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

          def add_link(account)
            name = name(account)
            key = Blog::Types::Normalized::LabelTag.call(name.split.first) { nil }
            query = { name:, "person[key]" => key, "person[#{HANDLES.fetch(@network)}]" => account.handle }

            Button(
              href: path(:admin_new_person, **query.compact), small: true, aria: { label: t(".add_label", name:) },
              data: { person_add: account.handle },
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
              add_link(account)
            end
          end

          def secure?(url) = url.to_s.start_with?(SECURE)
        end
      end
    end
  end
end
