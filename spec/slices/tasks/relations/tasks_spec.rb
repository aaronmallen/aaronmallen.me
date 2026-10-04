# frozen_string_literal: true

RSpec.describe Tasks::Relations::Tasks do
  it "refuses a canceled task without a close time" do
    expect { create(:task, status: "canceled") }.to raise_error(ROM::SQL::CheckConstraintError)
  end
end
