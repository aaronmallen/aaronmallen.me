# frozen_string_literal: true

RSpec.describe Notes::Operations::EditNote do
  def run(name, *) = Notes::Slice["operations.#{name}"].call(*)

  def stored(id) = Notes::Slice["repos.note_queries"].by_id(id)

  it "saves the title, body and tags sent against the version read, and counts the version on", :aggregate_failures do
    note = create(:note)
    params = { title: "Post ideas", body: "More", tags: ["writing"], version: note.version }
    edited = run(:edit_note, note.id, params).value!

    expect(edited).to have_attributes(title: "Post ideas", body: "More", version: note.version + 1)
    expect(edited.tags.map(&:name)).to eq(%w[writing])
  end

  it "keeps the tags when the edit sends none" do
    note = create(:note, tags: %w[ruby])
    run(:edit_note, note.id, { body: "Changed", version: note.version })

    expect(stored(note.id).tags.map(&:name)).to eq(%w[ruby])
  end

  it "refuses an edit sent against a note that changed since it was read", :aggregate_failures do
    note = create(:note, body: "First")
    run(:pin_note, note.id, { pinned: true })

    expect(run(:edit_note, note.id, { body: "Lost", version: note.version }))
      .to eq(Dry::Monads::Failure([:invalid, { version: ["changed"] }]))
    expect(stored(note.id).body).to eq("First")
  end

  it "refuses an edit that names no version" do
    note = create(:note)

    expect(run(:edit_note, note.id, { body: "No version" }).failure).to match([:invalid, { version: [anything] }])
  end

  it "refuses a title another note holds" do
    create(:note, title: "Taken")
    note = create(:note)

    expect(run(:edit_note, note.id, { title: "taken", version: note.version }))
      .to eq(Dry::Monads::Failure([:invalid, { title: ["taken"] }]))
  end

  it "answers not found for a note that does not exist" do
    expect(run(:edit_note, 999_999, { body: "x", version: 1 })).to eq(Dry::Monads::Failure(:not_found))
  end
end
