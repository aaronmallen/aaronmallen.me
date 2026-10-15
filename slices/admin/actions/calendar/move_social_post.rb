# frozen_string_literal: true

module Admin
  module Actions
    module Calendar
      class MoveSocialPost < Action
        include Redirect
        include Deps[move_social_post: "social.operations.move_social_post"]

        def handle(request, response) = move(request, response, move_social_post, at: :posted_at)
      end
    end
  end
end
