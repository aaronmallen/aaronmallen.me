# frozen_string_literal: true

module Posts
  module Relations
    class Tags < Blog::DB::Relation
      use :tags

      PROJECT = Blog::Types::TagScope["project"]
      PUBLIC = Blog::Types::TagScope["public"]

      schema :tags, infer: true

      def project_in_name_order = where(scope: PROJECT).in_name_order

      def public_in_name_order = where(scope: PUBLIC).in_name_order

      def ranked_by(counts)
        counted = dataset.unordered.join(counts.from_self(alias: :counted), tag_id: :id)
        counted.order(Sequel.desc(:count), :name).select(:name, :color, :count)
      end
    end
  end
end
