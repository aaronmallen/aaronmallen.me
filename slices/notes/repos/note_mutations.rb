# frozen_string_literal: true

module Notes
  module Repos
    class NoteMutations < Blog::DB::Repo
      root :notes

      stamped_commands :create, :update
      commands delete: :by_pk
      tagged_by :note_tags

      def move_out(folder_id, parent_id) = notes.where(folder_id:).update(folder_id: parent_id, updated_at: Time.now)

      def relink(from, to)
        notes.where(id: note_links.linking(from).select(:note_id).dataset).select(:id, :body).to_a.each do |note|
          body = Markdown::WikiLinks.rewrite(note.body, from, to)
          update(note.id, body:)
          store_links(note.id, body)
        end
      end

      def store_links(id, body)
        note_links.where(note_id: id).delete
        rows = Markdown::WikiLinks.titles(body).map { { note_id: id, title: it } }
        note_links.dataset.multi_insert(rows) unless rows.empty?
      end
    end
  end
end
