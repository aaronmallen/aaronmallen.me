# frozen_string_literal: true

RSpec.describe Notes::Operations::TagNote do
  def run(name, *) = Notes::Slice["operations.#{name}"].call(*)

  it "adds one private tag and counts the version on", :aggregate_failures do
    note = create(:note, tags: %w[ruby])
    tagged = run(:tag_note, note.id, "oss").value!

    expect(tagged.tags.map(&:name)).to eq(%w[oss ruby])
    expect(tagged.version).to eq(note.version + 1)
  end

  it "answers not found for a note that does not exist" do
    expect(run(:tag_note, 999_999, "oss")).to eq(Dry::Monads::Failure(:not_found))
  end
end
