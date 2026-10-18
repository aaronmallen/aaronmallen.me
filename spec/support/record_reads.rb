# frozen_string_literal: true

module Spec
  module RecordReads
    def open_in_list(list) = Tasks::Slice["repos.task_queries"].tasks.detailed.in_list(list).open.in_order.to_a

    def open_tasks = Tasks::Slice["repos.task_queries"].tasks.open.in_order.to_a

    def posts_by_status(status)
      Posts::Slice["repos.post_queries"].posts.combine(:tags).with_status(status).newest_first.to_a
    end

    def social_posts_in(queue)
      Social::Slice["repos.social_post_queries"].by_filter(queue, Blog::Structs::Page.new(number: 1, size: 100)).rows
    end
  end
end

RSpec.configure do |config|
  config.include Spec::RecordReads
end
