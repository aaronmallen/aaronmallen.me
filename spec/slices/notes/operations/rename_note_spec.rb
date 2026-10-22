# frozen_string_literal: true

RSpec.describe Notes::Operations::RenameNote do
  def run(name, *) = Notes::Slice["operations.#{name}"].call(*)

  it "changes the title" do
    note = create(:note)

    expect(run(:rename_note, note.id, { title: "Renamed" }).value!.title).to eq("Renamed")
  end

  it "refuses a title another note holds" do
    create(:note, title: "Taken")
    note = create(:note)

    expect(run(:rename_note, note.id, { title: "TAKEN" }))
      .to eq(Dry::Monads::Failure([:invalid, { title: ["taken"] }]))
  end

  it "answers not found for a note that does not exist" do
    expect(run(:rename_note, 999_999, { title: "Gone" })).to eq(Dry::Monads::Failure(:not_found))
  end
end
