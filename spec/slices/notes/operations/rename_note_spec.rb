# frozen_string_literal: true

RSpec.describe Notes::Operations::RenameNote do
  def run(name, *) = Notes::Slice["operations.#{name}"].call(*)

  it "changes the title" do
    note = create(:note)

    expect(run(:rename_note, note.id, { title: "Renamed" }).value!.title).to eq("Renamed")
  end

  describe "a note other notes link" do
    let(:queries) { Notes::Slice["repos.note_queries"] }
    let!(:note) { run(:create_note, { title: "Ruby", body: "See [[ruby]]" }).value! }
    let!(:linking) do
      [{ title: "Rails", body: "On [[Ruby]] and [[Rack]]" }, { title: "Gems", body: "[[ RUBY |the language]]" }]
        .map { run(:create_note, it).value! }
    end

    before { run(:rename_note, note.id, { title: "Crystal" }) }

    it "rewrites the old title in every note that links it, its own body included, and keeps the rest" do
      expect([note, *linking].map { queries.by_id(it.id).body })
        .to eq(["See [[Crystal]]", "On [[Crystal]] and [[Rack]]", "[[Crystal|the language]]"])
    end

    it "keeps its backlinks under the new title" do
      expect(queries.backlinks(queries.by_id(note.id)).map(&:title)).to eq(%w[Gems Rails])
    end
  end

  it "rewrites nothing when a refused title rolls the rename back" do
    run(:create_note, { title: "Taken" })
    note = run(:create_note, { title: "Ruby" }).value!
    rails = run(:create_note, { title: "Rails", body: "[[Ruby]]" }).value!
    run(:rename_note, note.id, { title: "taken" })

    expect(Notes::Slice["repos.note_queries"].by_id(rails.id).body).to eq("[[Ruby]]")
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
