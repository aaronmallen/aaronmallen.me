# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Social
        class Mentions < Component
          GROUPS = {
            both: ".groups.both",
            mastodon: ".groups.mastodon",
            bluesky: ".groups.bluesky",
          }.freeze
          LIST_ID = "social-mentions"

          prop :people, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            list
            status
            noscript { p(class: "hint") { add_link(id: nil) } }
            Directory(people: @people)
          end

          private

          def add_link(**)
            a(href: path(:admin_new_person), **) do
              IconLabel(icon: "fa-solid fa-plus") { t(".add") }
            end
          end

          def add_option
            add_link(
              id: "#{LIST_ID}-new", class: "compose-mention compose-mention-add", role: "option", tabindex: "-1",
              aria: { selected: "false" }, data: { social_mention_add: "" },
            )
          end

          def group(name, people)
            id = "#{LIST_ID}-group-#{name}"

            div(role: "group", aria: { labelledby: id }, hidden: people.empty?, data: { social_mention_group: name }) do
              p(id:, class: "compose-mention-group") { t(GROUPS.fetch(name)) }
              people.each { MentionOption(person: it) }
            end
          end

          def list
            div(
              id: LIST_ID, class: "compose-mentions", role: "listbox", hidden: true,
              aria: { label: t(".label") }, data: { social_mentions: "" },
            ) do
              networks = @people.group_by { MentionOption.group_of(it) }
              GROUPS.each_key { |name| group(name, networks.fetch(name, Blog::Constants::EMPTY_ARRAY)) }
              add_option
            end
          end

          def status
            p(
              class: "sr-only", role: "status",
              data: {
                social_mention_status: "", social_mention_chosen: t(".chosen"),
                social_mention_results_one: t(".results.one"), social_mention_results_other: t(".results.other"),
              },
            )
          end
        end
      end
    end
  end
end
