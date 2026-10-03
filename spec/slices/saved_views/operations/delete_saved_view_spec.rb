# frozen_string_literal: true

RSpec.describe SavedViews::Operations::DeleteSavedView do
  include Dry::Monads[:result]

  def delete(id) = SavedViews::Slice["operations.delete_saved_view"].call(id)

  def relation = SavedViews::Slice["relations.saved_views"]

  it "deletes the view" do
    view = create(:saved_view)
    delete(view.id)

    expect(relation.by_pk(view.id).one).to be_nil
  end

  it "leaves other views alone" do
    view = create(:saved_view)
    kept = create(:saved_view)
    delete(view.id)

    expect(relation.pluck(:id)).to eq([kept.id])
  end

  it "fails for an unknown view" do
    expect(delete(0)).to eq(Failure(:not_found))
  end
end
