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
      json.should contain(%("model":"claude-sonnet-4-5-20250929"))
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

  describe "#with_stream" do
    it "returns a copy with stream set to true" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024
      )

      stream_request = request.with_stream(true)

      # Original should not be mutated
      request.stream.should be_nil

      # Copy should have stream set
      stream_request.stream.should be_true
    end

    it "returns a copy with stream set to false" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        stream: true
      )

      stream_request = request.with_stream(false)

      # Original should not be mutated
      request.stream.should be_true

      # Copy should have stream set to false
      stream_request.stream.should be_false
    end

    it "serializes with stream true when using with_stream" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024
      )

      stream_request = request.with_stream(true)
      JSON.parse(stream_request.to_json)["stream"].as_bool.should be_true
    end

    it "copies all other fields correctly" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.opus,
        messages: [Anthropic::Message.user("Test")],
        max_tokens: 512,
        system: "Be helpful",
        temperature: 0.5,
        top_p: 0.9
      )

      stream_request = request.with_stream(true)

      stream_request.model.should eq(request.model)
      stream_request.messages.should eq(request.messages)
      stream_request.max_tokens.should eq(request.max_tokens)
      stream_request.system.should eq(request.system)
      stream_request.temperature.should eq(request.temperature)
      stream_request.top_p.should eq(request.top_p)
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
        model: Anthropic::Model::ClaudeOpus4_6,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024
      )
      request.model.should be_a(Anthropic::Model)
      request.model.should eq(Anthropic::Model::ClaudeOpus4_6)
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

  describe "validation" do
    it "raises on max_tokens = 0" do
      expect_raises(ArgumentError, "max_tokens must be positive") do
        Anthropic::Messages::Request.new(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hello!")],
          max_tokens: 0
        )
      end
    end

    it "raises on negative max_tokens" do
      expect_raises(ArgumentError, "max_tokens must be positive") do
        Anthropic::Messages::Request.new(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hello!")],
          max_tokens: -1
        )
      end
    end

    it "raises on empty messages array" do
      expect_raises(ArgumentError, "messages must not be empty") do
        Anthropic::Messages::Request.new(
          model: Anthropic::Model.sonnet,
          messages: [] of Anthropic::Message,
          max_tokens: 1024
        )
      end
    end

    it "raises on temperature > 1.0" do
      expect_raises(ArgumentError, "temperature must be between 0.0 and 1.0") do
        Anthropic::Messages::Request.new(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hello!")],
          max_tokens: 1024,
          temperature: 1.5
        )
      end
    end

    it "raises on temperature < 0.0" do
      expect_raises(ArgumentError, "temperature must be between 0.0 and 1.0") do
        Anthropic::Messages::Request.new(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hello!")],
          max_tokens: 1024,
          temperature: -0.1
        )
      end
    end

    it "raises on top_p > 1.0" do
      expect_raises(ArgumentError, "top_p must be between 0.0 and 1.0") do
        Anthropic::Messages::Request.new(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hello!")],
          max_tokens: 1024,
          top_p: 1.5
        )
      end
    end

    it "raises on top_p < 0.0" do
      expect_raises(ArgumentError, "top_p must be between 0.0 and 1.0") do
        Anthropic::Messages::Request.new(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hello!")],
          max_tokens: 1024,
          top_p: -0.1
        )
      end
    end

    it "accepts temperature = 0.0" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        temperature: 0.0
      )
      request.temperature.should eq(0.0)
    end

    it "accepts temperature = 1.0" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        temperature: 1.0
      )
      request.temperature.should eq(1.0)
    end

    it "accepts top_p = 0.0" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        top_p: 0.0
      )
      request.top_p.should eq(0.0)
    end

    it "accepts top_p = 1.0" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        top_p: 1.0
      )
      request.top_p.should eq(1.0)
    end

    it "accepts valid request with all params" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        temperature: 0.7,
        top_p: 0.9
      )
      request.temperature.should eq(0.7)
      request.top_p.should eq(0.9)
    end
  end
end
