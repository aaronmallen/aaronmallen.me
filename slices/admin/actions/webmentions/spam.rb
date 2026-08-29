# frozen_string_literal: true

module Admin
  module Actions
    module Webmentions
      class Spam < Action
        VERDICT = Blog::Types::WebmentionStatus["spam"]

        include Deps[moderate_webmention: "social.operations.moderate_webmention"]

        include Moderation
      end
    end
  end
end
