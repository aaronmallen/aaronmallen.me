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
          HANDLE_SEPARATOR = " · "
          LIST_ID = "social-mentions"

          prop :people, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            return if @people.empty?

            list
            status
          end

          private

          def group(name, people)
            id = "#{LIST_ID}-group-#{name}"

            div(role: "group", aria: { labelledby: id }, data: { social_mention_group: "" }) do
              p(id:, class: "compose-mention-group") { t(GROUPS.fetch(name)) }
              people.each { option(it) }
            end
          end

          def handles(person) = [person.mastodon_handle, person.bluesky_handle].compact

          def list
            div(
              id: LIST_ID, class: "compose-mentions", role: "listbox", hidden: true,
              aria: { label: t(".label") }, data: { social_mentions: "" },
            ) do
              networks = @people.group_by { network_group(it) }
              GROUPS.each_key { |name| group(name, networks[name]) if networks.key?(name) }
            end
          end

          def network_group(person)
            return :both if person.mastodon_handle && person.bluesky_handle

            person.mastodon_handle ? :mastodon : :bluesky
          end

          def option(person)
            div(
              id: "#{LIST_ID}-#{person.key}", class: "compose-mention", role: "option", aria: { selected: "false" },
              data: { social_mention: person.key, social_mention_name: person.name, social_mention_text: text(person) },
            ) do
              span(class: "compose-mention-name") { person.name }
              span(class: "compose-mention-handles") { handles(person).join(HANDLE_SEPARATOR) }
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

          def text(person) = [person.name, person.key, *handles(person)].join(" ").downcase
        end
      end
    end
  end
end
