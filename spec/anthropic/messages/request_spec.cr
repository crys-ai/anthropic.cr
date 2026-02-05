require "../../spec_helper"

describe Anthropic::Messages::Request do
  describe "#initialize" do
    it "creates with required params" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model::ClaudeSonnet4_5,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024
      )
      request.model.should eq(Anthropic::Model::ClaudeSonnet4_5)
      request.messages.size.should eq(1)
      request.max_tokens.should eq(1024)
    end

    it "accepts optional params" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        system: "Be helpful.",
        temperature: 0.7
      )
      request.system.should eq("Be helpful.")
      request.temperature.should eq(0.7)
    end
  end

  describe "JSON" do
    it "serializes model to API string" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model::ClaudeSonnet4_5,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024
      )
      json = request.to_json
      json.should contain(%("model":"claude-sonnet-4-5-20251101"))
      json.should contain(%("max_tokens":1024))
    end

    it "omits nil fields" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024
      )
      json = request.to_json
      json.should_not contain("temperature")
      json.should_not contain("system")
    end
  end
end
