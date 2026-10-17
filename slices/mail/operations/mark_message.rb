# frozen_string_literal: true

module Mail
  module Operations
    class MarkMessage < Blog::Operation
      include Deps[change_thread: "operations.change_thread"]

      def call(id, status, **) = step change_thread.call(id, status, **)
    end
  end
end
