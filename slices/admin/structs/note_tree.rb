# frozen_string_literal: true

module Admin
  module Structs
    NoteTree = Data.define(:id, :name, :description, :path, :folders, :notes) do
      def self.branch(folder, path, under, filed)
        new(
          id: folder&.id, name: folder&.name.to_s, description: folder&.description.to_s, path:,
          notes: filed.fetch(folder&.id, []),
          folders: under.fetch(folder&.id, []).map do |child|
            branch(child, [path, child.name].reject(&:empty?).join("/"), under, filed)
          end,
        )
      end

      def self.grow(folders, notes) = branch(nil, "", folders.group_by(&:parent_id), notes.group_by(&:folder_id))

      def all = folders.flat_map { [it, *it.all] }

      def count = notes.size + folders.sum(&:count)

      def empty? = notes.empty? && folders.empty?

      def find(id) = all.find { it.id == id }

      def path_of(id) = find(id)&.path.to_s

      def trail(id)
        folders.each do |folder|
          return [folder] if folder.id == id

          below = folder.trail(id)
          return [folder, *below] unless below.empty?
        end

        []
      end
    end
  end
end
