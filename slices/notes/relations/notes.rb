# frozen_string_literal: true

module Notes
  module Relations
    class Notes < Blog::DB::Relation
      use :tagged, through: :note_tags

      schema :notes, infer: true do
        associations do
          has_many :note_tags
          has_many :tags, through: :note_tags, view: :in_name_order
        end
      end

      def titled_from(base) = where(Sequel.ilike(:title, "#{dataset.escape_like(base)}%"))

      def titles_first(text)
        titled = Sequel.case([[Sequel.ilike(:title, like_pattern(text)), 0]], 1)

        order(titled, Sequel.desc(:updated_at), Sequel.desc(:id))
      end
    end
  end
end
