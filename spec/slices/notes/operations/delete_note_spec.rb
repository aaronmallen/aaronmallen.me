# frozen_string_literal: true

RSpec.describe Notes::Operations::DeleteNote do
  def run(name, *) = Notes::Slice["operations.#{name}"].call(*)

  def stored(id) = Notes::Slice["repos.note_queries"].by_id(id)

  it "deletes the note and its tags", :aggregate_failures do
    note = create(:note, tags: %w[ruby])

    expect(run(:delete_note, note.id)).to be_success
    expect(stored(note.id)).to be_nil
    expect(Notes::Slice["relations.note_tags"].where(note_id: note.id).count).to eq(0)
  end

  it "answers not found for a note that does not exist" do
    expect(run(:delete_note, 999_999)).to eq(Dry::Monads::Failure(:not_found))
  end
end
