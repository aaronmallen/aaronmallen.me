# frozen_string_literal: true

RSpec.describe "Admin events", type: :request do
  it "sends a visitor who is not signed in to sign in", :aggregate_failures do
    get "/admin/events"

    expect(last_response.status).to eq(302)
    expect(last_response.location).to eq("/admin/sign-in")
  end
end
