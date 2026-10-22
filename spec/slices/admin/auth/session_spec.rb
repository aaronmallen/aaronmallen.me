# frozen_string_literal: true

RSpec.describe Admin::Auth::Session do
  subject(:session) { described_class.new(store) }

  let(:devices) { Security::Slice["db.rom"].gateways[:default].connection[:devices] }
  let(:device) { Security::Slice["repos.device_mutations"].sign_in(nil) }
  let(:store) { Class.new(Hash) { def options = @options ||= {} }.new }

  def signed_in_session(now: Time.now)
    described_class.new(store, now:).tap { it.sign_in(Spec::AdminSession::EMAIL, device:) }
    described_class.new(store)
  end

  it "answers signed in after signing in within the same request", :aggregate_failures do
    expect(session).not_to be_signed_in

    session.sign_in(Spec::AdminSession::EMAIL, device:)

    expect(session).to be_signed_in
  end

  it "answers signed out after signing out within the same request", :aggregate_failures do
    session.sign_in(Spec::AdminSession::EMAIL, device:)
    expect(session).to be_signed_in

    session.sign_out

    expect(session).not_to be_signed_in
  end

  it "keeps the device in the session" do
    session.sign_in(Spec::AdminSession::EMAIL, device:)

    expect(store["device_id"]).to eq(device)
  end

  it "refuses a session that names no device" do
    session.sign_in(Spec::AdminSession::EMAIL, device: nil)

    expect(session).not_to be_signed_in
  end

  it "refuses a session whose device is gone" do
    signed = signed_in_session
    devices.delete

    expect(signed).not_to be_signed_in
  end

  it "refuses a session that began when its device was signed out" do
    now = Time.at(Time.now.to_i)
    signed = signed_in_session(now:)
    devices.update(signed_out_at: now)

    expect(signed).not_to be_signed_in
  end

  it "keeps a session that began after its device was signed out" do
    signed = signed_in_session
    devices.update(signed_out_at: Time.now - 60)

    expect(signed).to be_signed_in
  end
end
