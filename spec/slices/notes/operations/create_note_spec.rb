# frozen_string_literal: true

RSpec.describe Notes::Operations::CreateNote do
  def run(name, *) = Notes::Slice["operations.#{name}"].call(*)

  it "stores the title, body and folder" do
    folder = create(:note_folder)
    note = run(:create_note, { title: " Coffee ratios ", body: "1:16", folder_id: folder.id }).value!

    expect(note).to have_attributes(title: "Coffee ratios", body: "1:16", folder_id: folder.id, pinned: false)
  end

  it "takes private tags", :aggregate_failures do
    note = run(:create_note, { title: "Coffee ratios", tags: "home, coffee" }).value!

    expect(note.tags.map(&:name)).to eq(%w[coffee home])
    expect(note.tags.map(&:scope)).to all(eq("private"))
  end

  it "names an untitled note Untitled, counting past the ones taken" do
    run(:create_note, {})
    run(:create_note, {})

    expect(run(:create_note, { title: "" }).value!.title).to eq("Untitled 3")
  end

  it "refuses a title another note holds in any case" do
    create(:note, title: "Coffee ratios")

    expect(run(:create_note, { title: "COFFEE RATIOS" }))
      .to eq(Dry::Monads::Failure([:invalid, { title: ["taken"] }]))
  end

  it "refuses a folder that does not exist" do
    expect(run(:create_note, { title: "Lost", folder_id: 999_999 }))
      .to eq(Dry::Monads::Failure([:invalid, { folder_id: ["missing"] }]))
  end

  context "with the database alone" do
    it "refuses two notes whose titles differ only in case" do
      create(:note, title: "Hanami slices")

      expect { create(:note, title: "hanami SLICES") }.to raise_error(ROM::SQL::UniqueConstraintError)
    end
  end
end
