# frozen_string_literal: true

module Posts
  module Relations
    class Tags < Blog::DB::Relation
      use :tags

      schema :tags, infer: true
    end
  end
end
