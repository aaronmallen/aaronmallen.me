# frozen_string_literal: true

module ContactStamps
  WAITED = 60

  def contact_stamp(age: WAITED) = Public::Slice["contact_stamp"].issue(Time.now - age)

  def stamped(fields, age: WAITED) = { stamp: contact_stamp(age:), **fields }
end

RSpec.configure do |config|
  config.include ContactStamps
end
