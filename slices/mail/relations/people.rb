# frozen_string_literal: true

module Mail
  module Relations
    class People < Blog::DB::Relation
      schema :people, infer: true
    end
  end
end
