# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Social
        class Directory < Component
          prop :people, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            div(hidden: true, data: { social_people: JSON.generate(handles) })
          end

          private

          def handles
            mentions = ::Social::Mentions.new(@people)

            Blog::Types::NetworkName.values.to_h { [it, mentions.handles(it)] }
          end
        end
      end
    end
  end
end
