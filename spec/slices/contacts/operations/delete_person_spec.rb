# frozen_string_literal: true

RSpec.describe Contacts::Operations::DeletePerson do
  let(:delete_person) { Contacts::Slice["operations.delete_person"] }
  let(:person_mutations) { Contacts::Slice["repos.person_mutations"] }
  let(:person_queries) { Contacts::Slice["repos.person_queries"] }
  let(:connection) { connect_contacts }
  let(:url) { "#{Contacts::Helpers::GooglePerson::API}/people/c1:deleteContact" }

  def linked = person_mutations.create(name: "Ada", google_connection_id: connection.id, google_id: "c1")

  it "deletes a linked contact in Google too", :aggregate_failures do
    person = linked
    deleted = stub_request(:delete, url).with(headers: { "Authorization" => "Bearer ya29.me" }).to_return(body: "{}")
    delete_person.call(person.id)

    expect(deleted).to have_been_made
    expect(person_queries.by_id(person.id)).to be_nil
  end

  it "deletes a contact Google already deleted" do
    person = linked
    stub_request(:delete, url).to_return(status: 404)
    delete_person.call(person.id)

    expect(person_queries.by_id(person.id)).to be_nil
  end

  it "keeps the contact when Google refuses", :aggregate_failures do
    person = linked
    stub_request(:delete, url).to_return(status: 500)

    expect(delete_person.call(person.id).failure).to eq([:google_failed, "Google answered 500"])
    expect(person_queries.by_id(person.id)).not_to be_nil
  end

  it "deletes a local contact without asking Google" do
    connection
    person = person_mutations.create(name: "Ada")
    delete_person.call(person.id)

    expect(person_queries.by_id(person.id)).to be_nil
  end
end
