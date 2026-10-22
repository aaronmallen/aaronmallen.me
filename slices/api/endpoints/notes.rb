# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module Notes
      FOLDER = Helpers::Schema.nullable(Helpers::Schema::ID).merge(
        description: "the folder to file it in, as list_note_folders gives it; null for the top level",
      ).freeze
      ID = Helpers::Schema::ID
      RELINKED = {
        type: "integer", description: "how many other notes had their [[links]] to the old title rewritten",
      }.freeze
      TITLE = { type: "string", description: "unique among notes, ignoring case" }.freeze

      NOTE_CONTRACT = ::Notes::Contracts::NoteContract
      FOLDER_CONTRACT = ::Notes::Contracts::NoteFolderContract

      CONTRACTS = [NOTE_CONTRACT, FOLDER_CONTRACT].freeze
      COMPLAINTS = {
        body: { "long" => "keep a note to #{NOTE_CONTRACT::BODY_LIMIT} characters" },
        description: { "long" => "keep a description to #{FOLDER_CONTRACT::DESCRIPTION_LIMIT} characters" },
        folder_id: { Blog::Contract::MISSING => "no note folder has that ID" },
        name: {
          Blog::Contract::BLANK => "name the folder first",
          "long" => "keep a name to #{FOLDER_CONTRACT::NAME_LIMIT} characters",
        },
        parent_id: {
          Blog::Contract::MISSING => "no note folder has that ID",
          "inside" => "a folder cannot move inside itself or a folder within it",
        },
        tags: { Blog::Contract::FORMAT => Helpers::Tags::REFUSAL },
        title: {
          Blog::Contract::BLANK => "give the note a title",
          "long" => "keep a title to #{NOTE_CONTRACT::TITLE_LIMIT} characters",
          "taken" => "another note has that title",
        },
        version: { "changed" => "the note changed since you read it; read_note gives the new version to edit" },
      }.freeze
    end
  end
end
