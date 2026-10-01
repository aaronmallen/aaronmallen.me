# frozen_string_literal: true

module Admin
  module UI
    module Views
      module People
        class Mention < View
          include Components::Social

          layout nil

          def initialize(person:)
            super()
            @person = person
          end

          def view_template
            MentionOption(person: @person)
            Directory(people: [@person])
          end
        end
      end
    end
  end
end
