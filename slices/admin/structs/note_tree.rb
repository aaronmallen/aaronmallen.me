# frozen_string_literal: true

module Admin
  module Structs
    NoteTree = Data.define(:id, :name, :path, :folders, :notes) do
      def self.grow(folders, notes)
        under = folders.group_by(&:parent_id)
        filed = notes.group_by(&:folder_id)
        branch = lambda do |folder, path|
          new(
            id: folder&.id, name: folder&.name.to_s, path:, notes: filed.fetch(folder&.id, []),
            folders: under.fetch(folder&.id, []).map { branch.call(it, [path, it.name].reject(&:empty?).join("/")) },
          )
        end

        branch.call(nil, "")
      end

      def all = folders.flat_map { [it, *it.all] }

      def count = notes.size + folders.sum(&:count)

      def empty? = notes.empty? && folders.empty?

      def find(id) = all.find { it.id == id }

      def path_of(id) = find(id)&.path.to_s
    end
  end
end
