# frozen_string_literal: true

module Social
  module Operations
    class SnoozeWebmentions < Blog::Operation
      include Deps[webmention_mutations: "repos.webmention_mutations"]

      def call(ids, ends_at)
        each_record(ids) { found(webmention_mutations.snooze(it, ends_at)) }
      end
    end
  end
end
