# frozen_string_literal: true

RSpec.describe Tasks::Relations::TaskComments do
  let(:task) { create(:task) }

  def remote(**fields)
    { provider: "github", remote_id: "IC_1", url: "https://github.com/a/b/issues/1#c1" }.merge(fields)
  end

  it "holds a local comment with no provider, remote id or url" do
    expect(create(:task_comment, task_id: task.id).remote_id).to be_nil
  end

  it "holds a synced comment with all three" do
    expect(create(:task_comment, task_id: task.id, **remote).provider).to eq("github")
  end

  %i[provider remote_id url].each do |field|
    it "refuses a synced comment with no #{field}" do
      expect { create(:task_comment, task_id: task.id, **remote(field => nil)) }
        .to raise_error(ROM::SQL::CheckConstraintError, /task_comments_remote_check/)
    end
  end

  it "refuses a second copy of the same remote comment" do
    create(:task_comment, task_id: task.id, **remote)

    expect { create(:task_comment, task_id: create(:task).id, **remote) }
      .to raise_error(ROM::SQL::UniqueConstraintError)
  end

  it "keeps the same remote id apart across providers" do
    create(:task_comment, task_id: task.id, **remote)

    expect(create(:task_comment, task_id: task.id, **remote(provider: "linear")).provider).to eq("linear")
  end

  it "refuses a blank body" do
    expect { create(:task_comment, task_id: task.id, body: " \n") }.to raise_error(ROM::SQL::CheckConstraintError)
  end
end
