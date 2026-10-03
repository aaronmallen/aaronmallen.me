# frozen_string_literal: true

module Social
  module Relations
    class SocialPosts < Blog::DB::Relation
      DATED = Sequel.function(:coalesce, Sequel[:social_posts][:posted_at], Sequel[:social_posts][:created_at])
      DRAFT = Blog::Types::SocialPostStatus["draft"]
      POSTED = Blog::Types::SocialPostStatus["posted"]
      SCHEDULED = Blog::Types::SocialPostStatus["scheduled"]

      schema :social_posts, infer: true do
        associations do
          has_many :social_post_deliveries, as: :deliveries, view: :in_network_order
          has_many :social_post_parts, as: :parts, view: :in_order
        end
      end

      def counts_by_status = unordered.select(:status) { integer.count(id).as(:count) }.group(:status)

      def dated_between(from, to) = where(DATED => from...to)

      def due_at(time) = with_status(SCHEDULED).where { posted_at <= time }

      def for_post(post_id) = where(post_id:)

      def in_unsent_order
        draft = { status: DRAFT }

        order(
          Sequel.case({ draft => 0 }, 1),
          Sequel.case({ draft => self[:posted_at] }, nil).desc,
          Sequel.case({ draft => self[:id] }, nil).desc,
          self[:posted_at].asc,
          self[:id].asc,
        )
      end

      def mark_posted(id, at:) = by_pk(id).unposted.stamped(:update).call(status: POSTED, posted_at: at)

      def newest_dated_first = order(Sequel.desc(DATED), self[:id].desc)

      def newest_first = order(self[:posted_at].desc, self[:id].desc)

      def oldest_first = order(self[:posted_at].asc, self[:id].asc)

      def posted_between(from, to) = where(posted_at: from...to)

      def posted_since(time) = with_status(POSTED).where { posted_at >= time }

      def scheduled_or_posted = with_status([SCHEDULED, POSTED])

      def unclaimed = exclude(id: dataset.db[:social_post_deliveries].select(:social_post_id))

      def unposted = exclude(status: POSTED)

      def with_status(status) = where(status:)
    end
  end
end
