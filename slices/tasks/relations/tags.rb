# frozen_string_literal: true

module Tasks
  module Relations
    class Tags < Blog::DB::Relation
      include Blog::DB::Tags

      schema :tags, infer: true
    end
  end
end
