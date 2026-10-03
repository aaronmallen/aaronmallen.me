# frozen_string_literal: true

module Decisions
  module Relations
    class Decisions < Blog::DB::Relation
      schema :decisions, infer: true do
        associations do
          has_many :decision_options, as: :options, view: :in_order
        end
      end
    end
  end
end
