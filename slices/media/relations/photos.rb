# frozen_string_literal: true

module Media
  module Relations
    class Photos < Blog::DB::Relation
      schema :photos, infer: true
    end
  end
end
