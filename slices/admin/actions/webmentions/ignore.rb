# frozen_string_literal: true

module Admin
  module Actions
    module Webmentions
      class Ignore < Action
        VERDICT = Blog::Types::WebmentionStatus["ignored"]

        include Deps[moderate_webmention: "social.operations.moderate_webmention"]

        include Moderation
      end
    end
  end
end
