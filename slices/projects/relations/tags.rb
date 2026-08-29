# frozen_string_literal: true

module Projects
  module Relations
    class Tags < Blog::DB::Relation
      include Blog::DB::Tags

      schema :tags, infer: true
    end
  end
end
