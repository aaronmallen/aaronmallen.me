# frozen_string_literal: true

RSpec.describe Notes::Operations::MoveNoteFolder do
  def folder(id) = Notes::Slice["repos.note_queries"].folder_by_id(id)

  def run(name, *) = Notes::Slice["operations.#{name}"].call(*)

  it "moves a folder under another and back to the top level", :aggregate_failures do
    parent = create(:note_folder)
    made = create(:note_folder)

    expect(run(:move_note_folder, made.id, { parent_id: parent.id }).value!.parent_id).to eq(parent.id)
    expect(run(:move_note_folder, made.id, { parent_id: nil }).value!.parent_id).to be_nil
  end

  context "with a folder inside a folder inside another" do
    let(:top) { create(:note_folder) }
    let(:bottom) { create(:note_folder, parent_id: create(:note_folder, parent_id: top.id).id) }
    let(:inside) { Dry::Monads::Failure([:invalid, { parent_id: ["inside"] }]) }

    it "refuses a move into itself" do
      expect(run(:move_note_folder, top.id, { parent_id: top.id })).to eq(inside)
    end

    it "refuses a move into a folder inside it", :aggregate_failures do
      expect(run(:move_note_folder, top.id, { parent_id: bottom.id })).to eq(inside)
      expect(folder(top.id).parent_id).to be_nil
    end
  end

  it "refuses a parent that does not exist" do
    made = create(:note_folder)

    expect(run(:move_note_folder, made.id, { parent_id: 999_999 }))
      .to eq(Dry::Monads::Failure([:invalid, { parent_id: ["missing"] }]))
  end
end
