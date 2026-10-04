# frozen_string_literal: true

RSpec.describe Tasks::Relations::TaskSources do
  let!(:source) { create(:task_source, remote_id: "I_kwDOAbc", url: "https://github.com/aaronmallen/blog/issues/7") }

  it "refuses a second source for the same issue" do
    expect { create(:task_source, remote_id: source.remote_id) }.to raise_error(ROM::SQL::UniqueConstraintError)
  end

  it "shares an id between a Linear issue and a GitHub one without a clash" do
    url = "https://linear.app/acme/issue/ABC-123/fix-the-feed"

    expect(create(:task_source, provider: "linear", remote_id: source.remote_id, url:).provider).to eq("linear")
  end
end
