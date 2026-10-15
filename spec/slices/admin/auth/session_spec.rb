# frozen_string_literal: true

RSpec.describe Admin::Auth::Session do
  subject(:session) { described_class.new(store) }

  let(:store) { Class.new(Hash) { def options = @options ||= {} }.new }

  it "answers signed in after signing in within the same request", :aggregate_failures do
    expect(session).not_to be_signed_in

    session.sign_in(Spec::AdminSession::EMAIL)

    expect(session).to be_signed_in
  end

  it "answers signed out after signing out within the same request", :aggregate_failures do
    session.sign_in(Spec::AdminSession::EMAIL)
    expect(session).to be_signed_in

    session.sign_out

    expect(session).not_to be_signed_in
  end
end
