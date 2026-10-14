# frozen_string_literal: true

module API
  module Helpers
    module Untrusted
      KEY = :api_untrusted

      Synced = Data.define(:task_id, :text)

      module_function

      def call(text) = marking? ? marked(text) : text

      def marked(text) = { untrusted: true, text: }

      def marking
        was = Fiber[KEY]
        Fiber[KEY] = true
        yield
      ensure
        Fiber[KEY] = was
      end

      def marking? = Fiber[KEY] == true

      def synced(task_id, text) = marking? ? Synced.new(task_id:, text:) : text
    end
  end
end
