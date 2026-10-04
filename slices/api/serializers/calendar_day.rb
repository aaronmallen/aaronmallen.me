# frozen_string_literal: true

module API
  module Serializers
    class CalendarDay < Serializer
      SCHEMA = Schema.object(
        {
          date: Schema::DAY,
          sprint: Schema.nullable(
            Schema.object(
              {
                id: Schema::INTEGER,
                task_count: { type: "integer", description: "the tasks planned into the sprint" },
              },
            ),
          ),
          posts: Schema.list(Post.reference),
          social_posts: Schema.list(SocialPost.reference),
          journal: { type: "boolean", description: "whether the journal holds an entry for the day" },
        },
      ).freeze

      attributes :date, :sprint, :posts, :social_posts, :journal

      def date(found) = day(found.date)

      def posts(found) = Post.new(found.posts).serializable_hash

      def social_posts(found) = SocialPost.new(found.social_posts).serializable_hash

      def sprint(found) = found.sprint&.then { { id: it.id, task_count: it.task_count } }
    end
  end
end
