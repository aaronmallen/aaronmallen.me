# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module SocialPosts
      module_function

      def missing(id) = "no social post has the ID #{id}"
    end
  end
end
