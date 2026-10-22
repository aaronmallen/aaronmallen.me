# frozen_string_literal: true

module Notes
  module Relations
    class NoteLinks < Blog::DB::Relation
      LINKED = Sequel.function(:lower, Sequel[:note_links][:title])
      NOTE_ID = Sequel[:notes][:id]
      SOURCE = Sequel[:sources][:title]

      schema :note_links, infer: true

      def backlink_counts(ids) = targets.where(NOTE_ID => ids).exclude(note_id: NOTE_ID).group_and_count(NOTE_ID)

      def linking(title) = where(LINKED => Sequel.function(:lower, title))

      def out(id)
        found = targets.where(note_id: id).order(LINKED)

        found.select(Sequel.function(:coalesce, Sequel[:notes][:title], self[:title].qualified).as(:title), NOTE_ID)
      end

      def unwritten
        found = targets.join(Sequel[:notes].as(:sources), id: self[:note_id].qualified).where(NOTE_ID => nil)
        found = found.order(LINKED, Sequel.function(:lower, SOURCE))

        found.select(self[:title].qualified, SOURCE.as(:source), Sequel[:sources][:folder_id])
      end

      private

      def targets = dataset.unordered.left_join(:notes, Sequel.function(:lower, Sequel[:notes][:title]) => LINKED)
    end
  end
end
