# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Social
        class MentionOption < Component
          HANDLE_SEPARATOR = " · "

          prop :person, Blog::Types::Instance(ROM::Struct)

          def self.group_of(person)
            return :both if person.mastodon_handle && person.bluesky_handle

            person.mastodon_handle ? :mastodon : :bluesky
          end

          def view_template
            div(
              id: "#{Mentions::LIST_ID}-#{@person.key}", class: "compose-mention", role: "option",
              aria: { selected: "false" }, data:,
            ) do
              span(class: "compose-mention-name") { @person.name }
              span(class: "compose-mention-handles") { handles.join(HANDLE_SEPARATOR) }
            end
          end

          private

          def data
            {
              social_mention: @person.key, social_mention_in: self.class.group_of(@person),
              social_mention_name: @person.name, social_mention_text: text,
            }
          end

          def handles = [@person.mastodon_handle, @person.bluesky_handle].compact

          def text = [@person.name, @person.key, *handles].join(" ").downcase
        end
      end
    end
  end
end
