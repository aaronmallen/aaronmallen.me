# frozen_string_literal: true

module Decisions
  module Relations
    class Decisions < Blog::DB::Relation
      schema :decisions, infer: true do
        associations do
          has_many :decision_options, as: :options, view: :in_order
        end
      end

      def linkable = linkables(title: :title, day: self.class.site_day(:created_at))

      def matching(text) = containing(text, :title, :problem)
    end
  end
end
