# frozen_string_literal: true

RSpec.describe Notes::Operations::DuplicateNote do
  def run(name, *) = Notes::Slice["operations.#{name}"].call(*)

  it "copies the body and folder under a free title", :aggregate_failures do
    folder = create(:note_folder)
    note = create(:note, title: "Checklist", body: "1. Tag", folder_id: folder.id)
    run(:duplicate_note, note.id)
    copy = run(:duplicate_note, note.id).value!

    expect(copy).to have_attributes(title: "Checklist copy 2", body: "1. Tag", folder_id: folder.id)
  end

  it "stores the copy's links, so the note it links counts it as a backlink" do
    ruby = create(:note, title: "Ruby")
    note = create(:note, title: "Rails", body: "On [[Ruby]]")
    run(:duplicate_note, note.id)

    expect(Notes::Slice["repos.note_queries"].backlinks(ruby).map(&:title)).to eq(["Rails copy"])
  end

  it "answers not found for a note that does not exist" do
    expect(run(:duplicate_note, 999_999)).to eq(Dry::Monads::Failure(:not_found))
  end
end
