# frozen_string_literal: true

module Admin
  module UI
    module Views
      module People
        class Mention < View
          include Components::Social

          layout nil

          prop :person, Blog::Types::Instance(ROM::Struct)

          def view_template
            MentionOption(person: @person)
            Directory(people: [@person])
          end
        end
      end
    end
  end
end
