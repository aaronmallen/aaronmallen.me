# frozen_string_literal: true

module Admin
  module Actions
    module Calendar
      class MovePost < Action
        include Move
        include Deps[move_post: "posts.operations.move_post"]

        def handle(request, response) = move(request, response, move_post, at: :published_at)
      end
    end
  end
end
