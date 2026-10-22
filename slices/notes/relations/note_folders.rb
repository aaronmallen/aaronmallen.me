# frozen_string_literal: true

module Notes
  module Relations
    class NoteFolders < Blog::DB::Relation
      schema :note_folders, infer: true
    end
  end
end
