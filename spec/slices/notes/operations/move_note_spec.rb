# frozen_string_literal: true

RSpec.describe Notes::Operations::MoveNote do
  def run(name, *) = Notes::Slice["operations.#{name}"].call(*)

  it "moves a note into a folder and back to the top level", :aggregate_failures do
    folder = create(:note_folder)
    note = create(:note)

    expect(run(:move_note, note.id, { folder_id: folder.id }).value!.folder_id).to eq(folder.id)
    expect(run(:move_note, note.id, { folder_id: nil }).value!.folder_id).to be_nil
  end

  it "refuses a folder that does not exist" do
    note = create(:note)

    expect(run(:move_note, note.id, { folder_id: 999_999 }))
      .to eq(Dry::Monads::Failure([:invalid, { folder_id: ["missing"] }]))
  end
end
