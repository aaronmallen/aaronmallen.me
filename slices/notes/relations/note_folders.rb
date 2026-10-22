# frozen_string_literal: true

module Notes
  module Relations
    class NoteFolders < Blog::DB::Relation
      schema :note_folders, infer: true

      def linkable = linkables(title: :name, day: self.class.site_day(:created_at))

      def matching(text) = containing(text, :name, :description)
    end
  end
end
