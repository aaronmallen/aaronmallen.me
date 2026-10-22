# frozen_string_literal: true

RSpec.describe Notes::Operations::RemoveNoteFolder do
  def folder(id) = Notes::Slice["repos.note_queries"].folder_by_id(id)

  def note(id) = Notes::Slice["repos.note_queries"].by_id(id)

  def run(name, *) = Notes::Slice["operations.#{name}"].call(*)

  context "with a folder inside another" do
    let(:top) { create(:note_folder) }
    let(:removed) { create(:note_folder, parent_id: top.id) }
    let(:child) { create(:note_folder, parent_id: removed.id) }

    it "removes the folder", :aggregate_failures do
      expect(run(:remove_note_folder, removed.id)).to be_success
      expect(folder(removed.id)).to be_nil
    end

    it "moves its notes up one level" do
      held = create(:note, folder_id: removed.id)
      run(:remove_note_folder, removed.id)

      expect(note(held.id).folder_id).to eq(top.id)
    end

    it "moves its subfolders up one level and leaves their notes in them", :aggregate_failures do
      deeper = create(:note, folder_id: child.id)
      run(:remove_note_folder, removed.id)

      expect(folder(child.id).parent_id).to eq(top.id)
      expect(note(deeper.id).folder_id).to eq(child.id)
    end
  end

  it "moves the notes of a top level folder to the top level" do
    removed = create(:note_folder)
    held = create(:note, folder_id: removed.id)
    run(:remove_note_folder, removed.id)

    expect(note(held.id).folder_id).to be_nil
  end

  it "answers not found for a folder that does not exist" do
    expect(run(:remove_note_folder, 999_999)).to eq(Dry::Monads::Failure(:not_found))
  end
end
