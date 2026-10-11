# frozen_string_literal: true

module Mail
  module Relations
    class Tags < Blog::DB::Relation
      use :tags

      schema :tags, infer: true
    end
  end
end
