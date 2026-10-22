# frozen_string_literal: true

RSpec.describe Notes::Operations::CreateNoteFolder do
  def folder(id) = Notes::Slice["repos.note_queries"].folder_by_id(id)

  def run(name, *) = Notes::Slice["operations.#{name}"].call(*)

  it "nests a described folder that holds no notes", :aggregate_failures do
    parent = create(:note_folder)
    created = run(:create_note_folder, { name: " Ruby ", description: "Gems", parent_id: parent.id }).value!

    expect(created).to have_attributes(name: "Ruby", description: "Gems", parent_id: parent.id)
    expect(folder(created.id)).not_to be_nil
  end

  it "refuses a parent that does not exist" do
    expect(run(:create_note_folder, { name: "Lost", parent_id: 999_999 }))
      .to eq(Dry::Monads::Failure([:invalid, { parent_id: ["missing"] }]))
  end

  it "refuses a blank name" do
    expect(run(:create_note_folder, { name: " " }).failure).to match([:invalid, { name: [anything] }])
  end
end
