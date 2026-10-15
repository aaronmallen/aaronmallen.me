# frozen_string_literal: true

module Posts
  module Relations
    class Tags < Blog::DB::Relation
      use :tags

      schema :tags, infer: true

      def ranked_by(counts)
        counted = dataset.unordered.join(counts.from_self(alias: :counted), tag_id: :id)
        counted.order(Sequel.desc(:count), :name).select(:name, :color, :count)
      end
    end
  end
end
