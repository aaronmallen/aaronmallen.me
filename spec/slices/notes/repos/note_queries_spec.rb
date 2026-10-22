# frozen_string_literal: true

RSpec.describe Notes::Repos::NoteQueries do
  subject(:queries) { Notes::Slice["repos.note_queries"] }

  def write(title, body = "", folder_id: nil)
    Notes::Slice["operations.create_note"].call({ title:, body:, folder_id: }).value!
  end

  it "lists the other notes that link to a note, in title order, whatever case the link takes" do
    ruby = write("Ruby", "[[Ruby]] links itself")
    write("Rails", "Built on [[ruby]]")
    write("Gems", "Packaged for [[Ruby|the language]]")
    write("Go")

    expect(queries.backlinks(ruby).map(&:title)).to eq(%w[Gems Rails])
  end

  it "counts the backlinks of each note it is asked about, leaving out a note's link to itself" do
    ruby = write("Ruby", "[[Ruby]]")
    go = write("Go")
    write("Rails", "[[Ruby]] and [[Go]]")
    write("Gems", "[[Ruby]]")

    expect(queries.backlink_counts([ruby.id, go.id])).to eq(ruby.id => 2, go.id => 1)
  end

  it "lists a note's links out, naming the note each finds and none for a note not written" do
    ruby = write("Ruby")
    rails = write("Rails", "On [[ruby]], see [[Hotwire]]")

    expect(queries.links_out(rails.id)).to eq([{ title: "Hotwire", id: nil }, { title: "Ruby", id: ruby.id }])
  end

  it "lists the titles linked but not written, with the notes that link them and the first one's folder" do
    folder = create(:note_folder)
    write("Rails", "[[Hotwire]] and [[Ruby]]", folder_id: folder.id)
    write("Turbo", "[[hotwire]]")
    write("Ruby")

    expect(queries.unwritten).to eq([{ title: "Hotwire", sources: %w[Rails Turbo], folder_id: folder.id }])
  end
end
