require "./spec_helper"

describe Anthropic do
  it "has a version" do
    Anthropic::VERSION.should_not be_empty
  end
end
