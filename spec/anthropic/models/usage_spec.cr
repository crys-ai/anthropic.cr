require "../../spec_helper"

describe Anthropic::Usage do
  describe "JSON" do
    it "parses basic usage" do
      usage = Anthropic::Usage.from_json(%({"input_tokens":25,"output_tokens":150}))
      usage.input_tokens.should eq(25)
      usage.output_tokens.should eq(150)
    end

    it "parses cache tokens" do
      json = %({"input_tokens":25,"output_tokens":150,"cache_creation_input_tokens":100,"cache_read_input_tokens":50})
      usage = Anthropic::Usage.from_json(json)
      usage.cache_creation_input_tokens.should eq(100)
      usage.cache_read_input_tokens.should eq(50)
    end

    it "handles missing cache tokens" do
      usage = Anthropic::Usage.from_json(%({"input_tokens":25,"output_tokens":150}))
      usage.cache_creation_input_tokens.should be_nil
      usage.cache_read_input_tokens.should be_nil
    end
  end

  describe "#total_tokens" do
    it "sums input and output" do
      usage = Anthropic::Usage.from_json(%({"input_tokens":25,"output_tokens":150}))
      usage.total_tokens.should eq(175)
    end
  end
end
