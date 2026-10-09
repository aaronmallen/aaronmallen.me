# frozen_string_literal: true

module Contact
  module Relations
    class Tags < Blog::DB::Relation
      use :tags

      schema :tags, infer: true
    end
  end
end
