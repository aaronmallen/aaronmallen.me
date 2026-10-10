# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Social
        class Directory < Component
          TOKEN = ::Social::Operations::ResolveMentions::TOKEN.source

          prop :handles, Blog::Types::Hash

          def view_template
            div(hidden: true, data: { social_people: JSON.generate(@handles), social_token: TOKEN })
          end
        end
      end
    end
  end
end
