# frozen_string_literal: true

module Notes
  module Relations
    class Notes < Blog::DB::Relation
      schema :notes, infer: true do
        associations do
          has_many :note_tags
          has_many :tags, through: :note_tags, view: :in_name_order
        end
      end

      def titled_from(base) = where(Sequel.ilike(:title, "#{dataset.escape_like(base)}%"))
    end
  end
end
