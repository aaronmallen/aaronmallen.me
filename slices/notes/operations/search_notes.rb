# frozen_string_literal: true

module Notes
  module Operations
    class SearchNotes
      TAG = /\A#([a-z0-9-]+)\z/

      include Deps[note_queries: "repos.note_queries"]

      def self.tag(text) = TAG.match(text.to_s.downcase)&.[](1)

      def call(query)
        text = Blog::Types::TrimmedText[query]
        return Blog::Constants::EMPTY_ARRAY if text.empty?

        name = self.class.tag(text)
        name ? note_queries.tagged(name) : note_queries.found(text, folder_ids: folder_ids(text.downcase))
      end

      private

      def folder_ids(folded) = paths(note_queries.folders).select { |_, path| path.downcase.include?(folded) }.keys

      def paths(folders)
        by_id = folders.to_h { [it.id, it] }
        paths = Hash.new do |found, id|
          folder = by_id.fetch(id)
          found[id] = [folder.parent_id && found[folder.parent_id], folder.name].compact.join("/")
        end
        by_id.each_key { paths[it] }
        paths
      end
    end
  end
end
