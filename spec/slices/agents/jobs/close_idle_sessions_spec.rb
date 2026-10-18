# frozen_string_literal: true

RSpec.describe Agents::Jobs::CloseIdleSessions, type: :request do
  subject(:job) { described_class.new }

  let(:session_id) do
    call_api(:post, "/agent_sessions", { title: "Spike", agent: "claude-code", model: "claude-opus-5-5" })
      .fetch("session_id")
  end

  def ended_at = call_api(:get, "/agent_sessions").fetch("sessions").first.fetch("ended_at")

  def later(seconds) = allow(Time).to receive(:now).and_return(Time.now + seconds)

  it "closes a session no call named for 2 hours" do
    session_id
    later((2 * 60 * 60) + 1)
    job.perform

    expect(ended_at).not_to be_nil
  end

  it "leaves a session seen within 2 hours open" do
    session_id
    later((2 * 60 * 60) - 60)
    job.perform

    expect(ended_at).to be_nil
  end
end
