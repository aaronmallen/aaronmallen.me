# frozen_string_literal: true

module Admin
  module UI
    module Views
      module People
        class Mention < View
          include Components::Social

          layout nil

          prop :handles, Blog::Types::Hash
          prop :person, Blog::Types::Instance(ROM::Struct)

          def view_template
            MentionOption(person: @person)
            Directory(handles: @handles)
          end
        end
      end
    end
  end
end
