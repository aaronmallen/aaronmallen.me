# frozen_string_literal: true

module Posts
  module Relations
    class Posts < Blog::DB::Relation
      PUBLISHED = Blog::Types::PostStatus["published"]
      SCHEDULED = Blog::Types::PostStatus["scheduled"]

      schema :posts, infer: true do
        associations do
          has_many :post_tags
          has_many :tags, through: :post_tags, view: :in_name_order
        end
      end

      def dated_between(first, last)
        started = first ? where { published_at >= first } : self
        last ? started.where { published_at < last } : started
      end

      def due_at(time) = with_status(SCHEDULED).where { published_at <= time }

      def linkable = linkables(title: :title, day: self.class.site_day(:published_at, :created_at))

      def matching(text) = containing(text, :title, :summary, :body)

      def newer_than(post) = where(published_order > [post.published_at, post.id])

      def newest_first = order(self[:published_at].desc, self[:id].desc)

      def older_than(post) = where(published_order < [post.published_at, post.id])

      def oldest_first = order(self[:published_at].asc, self[:id].asc)

      def publish(at)
        published_at = Sequel.function(:least, Sequel.function(:coalesce, :published_at, at), at)

        stamped(:update, result: :many).call(status: PUBLISHED, published_at:)
      end

      def published = where(status: PUBLISHED)

      def scheduled = with_status(SCHEDULED)

      def scheduled_or_published = with_status([SCHEDULED, PUBLISHED])

      def tagged(tag) = join(:tags).where(Sequel[:tags][:name] => tag)

      def unpublished = exclude(status: PUBLISHED)

      def with_ids(ids) = where(id: ids)

      def with_slug(slug) = where(slug:)

      def with_status(status) = where(status:)

      private

      def published_order = Sequel.expr([self[:published_at], self[:id]])
    end
  end
end
