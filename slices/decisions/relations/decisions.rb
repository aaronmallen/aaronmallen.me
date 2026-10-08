# frozen_string_literal: true

module Decisions
  module Relations
    class Decisions < Blog::DB::Relation
      schema :decisions, infer: true do
        associations do
          has_many :decision_comments, as: :comments
          has_many :decision_options, as: :options, view: :in_order
          has_many :decision_tags
          has_many :tags, through: :decision_tags, view: :in_name_order
        end
      end

      def counts_by_status = unordered.select(:status) { integer.count(id).as(:count) }.group(:status)

      def linkable = linkables(title: :title, day: self.class.site_day(:created_at))

      def matching(text) = containing(text, :title, :problem)

      def newest_first = order(self[:created_at].desc, self[:id].desc)

      def tagged(name)
        owner = decision_tags[:decision_id].qualified

        where(id: decision_tags.unordered.join(:tag).where(tags[:name].qualified => name).select(owner).dataset)
      end

      def with_status(status) = where(status:)
    end
  end
end
