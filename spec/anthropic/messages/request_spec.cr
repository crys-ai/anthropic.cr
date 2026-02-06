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

    it "serializes stream true" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        stream: true
      )
      JSON.parse(request.to_json)["stream"].as_bool.should be_true
    end

    it "serializes stream false" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        stream: false
      )
      JSON.parse(request.to_json)["stream"].as_bool.should be_false
    end
  end

  describe "custom model strings" do
    it "accepts custom model string" do
      request = Anthropic::Messages::Request.new(
        model: "claude-custom-model-2026",
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024
      )
      request.model.should eq("claude-custom-model-2026")
    end

    it "stores custom model as String type" do
      request = Anthropic::Messages::Request.new(
        model: "custom-model",
        messages: [Anthropic::Message.user("Test")],
        max_tokens: 512
      )
      request.model.should be_a(String)
    end

    it "serializes custom model string to JSON" do
      request = Anthropic::Messages::Request.new(
        model: "claude-experimental-v2",
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024
      )
      json = request.to_json
      json.should contain(%("model":"claude-experimental-v2"))
    end

    it "preserves Model enum when using enum constructor" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model::ClaudeOpus4_5,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024
      )
      request.model.should be_a(Anthropic::Model)
      request.model.should eq(Anthropic::Model::ClaudeOpus4_5)
    end

    it "both constructors work correctly" do
      enum_request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Test")],
        max_tokens: 100
      )
      string_request = Anthropic::Messages::Request.new(
        model: "custom-model",
        messages: [Anthropic::Message.user("Test")],
        max_tokens: 100
      )

      enum_request.model.should be_a(Anthropic::Model)
      string_request.model.should be_a(String)
    end
  end
end
