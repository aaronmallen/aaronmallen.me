# frozen_string_literal: true

RSpec.describe Notes::Operations::RenameNoteFolder do
  def run(name, *) = Notes::Slice["operations.#{name}"].call(*)

  it "changes the name" do
    made = create(:note_folder)

    expect(run(:rename_note_folder, made.id, { name: " Home " }).value!.name).to eq("Home")
  end

  it "answers not found for a folder that does not exist" do
    expect(run(:rename_note_folder, 999_999, { name: "Gone" })).to eq(Dry::Monads::Failure(:not_found))
  end
end
