# frozen_string_literal: true

RSpec.describe Notes::Operations::UntagNote do
  def run(name, *) = Notes::Slice["operations.#{name}"].call(*)

  it "takes off one tag" do
    note = create(:note, tags: %w[oss ruby])

    expect(run(:untag_note, note.id, "ruby").value!.tags.map(&:name)).to eq(%w[oss])
  end
end
