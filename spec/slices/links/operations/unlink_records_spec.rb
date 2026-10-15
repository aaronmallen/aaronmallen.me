# frozen_string_literal: true

RSpec.describe Links::Operations::UnlinkRecords do
  let(:task) { create(:task) }

  def unlink(*sides) = Links::Slice["operations.unlink_records"].call(*sides)

  it "refuses an unknown kind as not found" do
    expect(unlink("task", task.id, "person", 1)).to eq(Dry::Monads::Failure(:not_found))
  end

  it "refuses an unknown kind on its own side as not found" do
    expect(unlink("person", 1, "task", task.id)).to eq(Dry::Monads::Failure(:not_found))
  end
end
