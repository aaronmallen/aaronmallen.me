# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class Avatar < Component
          FIELDS = Blog::Types::Hash | Blog::Types::Instance(ROM::Struct)

          prop :person, FIELDS
          prop :large, Blog::Types::Bool, default: false

          def self.initials(person)
            letters = [person[:given_name], person[:family_name]].filter_map { it.to_s[0] }.join
            letters = name_of(person).to_s[0, 2] if letters.empty?
            letters.upcase
          end

          def self.name_of(person) = person[:name] || person[:company]

          def view_template
            initials = self.class.initials(@person)

            span(class: @large ? "contact-avatar" : "contact-row-avatar", aria: { hidden: "true" }) do
              initials.empty? ? Icon("fa-regular fa-user") : plain(initials)
            end
          end
        end
      end
    end
  end
end
