# frozen_string_literal: true

RSpec.describe Notes::Operations::PinNote do
  def run(name, *) = Notes::Slice["operations.#{name}"].call(*)

  it "pins and unpins a note", :aggregate_failures do
    note = create(:note)

    expect(run(:pin_note, note.id, { pinned: true }).value!.pinned).to be(true)
    expect(run(:pin_note, note.id, { pinned: false }).value!.pinned).to be(false)
  end
end
