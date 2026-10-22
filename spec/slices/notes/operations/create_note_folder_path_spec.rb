# frozen_string_literal: true

RSpec.describe Notes::Operations::CreateNoteFolderPath do
  def run(path) = Notes::Slice["operations.create_note_folder_path"].call(path)

  it "makes each folder on a path, nested in the one before", :aggregate_failures do
    made = run(" work / clients ").value!
    parent = Notes::Slice["repos.note_queries"].folder_by_id(made.parent_id)

    expect(made.name).to eq("clients")
    expect(parent).to have_attributes(name: "work", parent_id: nil)
  end

  it "reuses the folders a path already names, whatever their case" do
    work = create(:note_folder, name: "Work")

    expect(run("work/clients").value!.parent_id).to eq(work.id)
  end

  it "answers the folder itself when the whole path exists" do
    work = create(:note_folder, name: "work")

    expect(run("work").value!.id).to eq(work.id)
  end

  it "answers no folder for an empty path" do
    expect(run(" / ").value!).to be_nil
  end

  it "makes nothing when a name on the path is refused", :aggregate_failures do
    expect(run("work/#{'x' * 101}").failure).to match([:invalid, { name: [anything] }])
    expect(Notes::Slice["repos.note_queries"].folders).to be_empty
  end
end
