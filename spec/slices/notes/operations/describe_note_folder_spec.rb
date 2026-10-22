# frozen_string_literal: true

RSpec.describe Notes::Operations::DescribeNoteFolder do
  def run(name, *) = Notes::Slice["operations.#{name}"].call(*)

  it "changes the description and can clear it", :aggregate_failures do
    made = create(:note_folder)

    expect(run(:describe_note_folder, made.id, { description: "Around the house" }).value!.description)
      .to eq("Around the house")
    expect(run(:describe_note_folder, made.id, { description: "" }).value!.description).to eq("")
  end

  it "answers not found for a folder that does not exist" do
    expect(run(:describe_note_folder, 999_999, { description: "Gone" })).to eq(Dry::Monads::Failure(:not_found))
  end
end
