require "../spec_helper"

describe Anthropic::ThinkingConfig do
  describe "#initialize" do
    it "creates with default type" do
      config = Anthropic::ThinkingConfig.new
      config.type.should eq("enabled")
    end

    it "creates with budget_tokens" do
      config = Anthropic::ThinkingConfig.new(budget_tokens: 10000)
      config.budget_tokens.should eq(10000)
    end

    it "creates without budget_tokens" do
      config = Anthropic::ThinkingConfig.new
      config.budget_tokens.should be_nil
    end
  end

  describe "#to_json" do
    it "serializes with budget_tokens" do
      config = Anthropic::ThinkingConfig.new(budget_tokens: 5000)
      json = JSON.parse(config.to_json)
      json["type"].as_s.should eq("enabled")
      json["budget_tokens"].as_i.should eq(5000)
    end

    it "omits budget_tokens when nil" do
      config = Anthropic::ThinkingConfig.new
      json = config.to_json
      json.should_not contain("budget_tokens")
    end

    it "serializes to correct structure" do
      config = Anthropic::ThinkingConfig.new(budget_tokens: 10000)
      json = config.to_json
      json.should eq(%({"type":"enabled","budget_tokens":10000}))
    end
  end
end

describe Anthropic::Content::ThinkingData do
  describe "#initialize" do
    it "creates with thinking text" do
      data = Anthropic::Content::ThinkingData.new("Let me think about this...")
      data.thinking.should eq("Let me think about this...")
    end

    it "creates with optional signature" do
      data = Anthropic::Content::ThinkingData.new("Reasoning...", signature: "abc123")
      data.signature?.should eq("abc123")
    end

    it "creates without signature" do
      data = Anthropic::Content::ThinkingData.new("Reasoning...")
      data.signature?.should be_nil
    end

    it "accepts empty string" do
      data = Anthropic::Content::ThinkingData.new("")
      data.thinking.should eq("")
    end
  end

  describe "#content_type" do
    it "returns Type::Thinking" do
      data = Anthropic::Content::ThinkingData.new("test")
      data.content_type.should eq(Anthropic::Content::Type::Thinking)
    end
  end

  describe "#to_content_json" do
    it "writes thinking field" do
      data = Anthropic::Content::ThinkingData.new("My reasoning...")
      json = JSON.build do |builder|
        builder.object do
          data.to_content_json(builder)
        end
      end
      json.should eq(%({"thinking":"My reasoning..."}))
    end

    it "writes signature when present" do
      data = Anthropic::Content::ThinkingData.new("Reasoning...", signature: "sig123")
      json = JSON.build do |builder|
        builder.object do
          data.to_content_json(builder)
        end
      end
      parsed = JSON.parse(json)
      parsed["thinking"].as_s.should eq("Reasoning...")
      parsed["signature"].as_s.should eq("sig123")
    end

    it "omits signature when nil" do
      data = Anthropic::Content::ThinkingData.new("Reasoning...")
      json = JSON.build do |builder|
        builder.object do
          data.to_content_json(builder)
        end
      end
      json.should_not contain("signature")
    end
  end

  describe "Data protocol conformance" do
    it "includes Data module" do
      data = Anthropic::Content::ThinkingData.new("test")
      data.should be_a(Anthropic::Content::Data)
    end
  end
end

describe "Content.thinking factory" do
  it "creates a thinking content block" do
    block = Anthropic::Content.thinking("Let me reason...")
    block.should be_a(Anthropic::Content::Block(Anthropic::Content::ThinkingData))
  end

  it "has correct type" do
    block = Anthropic::Content.thinking("Reasoning...")
    block.type.should eq(Anthropic::Content::Type::Thinking)
  end

  it "exposes thinking data" do
    block = Anthropic::Content.thinking("Deep thoughts...")
    block.data.thinking.should eq("Deep thoughts...")
  end

  it "creates with signature" do
    block = Anthropic::Content.thinking("Reasoning...", signature: "sig123")
    block.data.signature?.should eq("sig123")
  end

  it "serializes to JSON" do
    block = Anthropic::Content.thinking("My reasoning...")
    json = block.to_json
    json.should eq(%({"type":"thinking","thinking":"My reasoning..."}))
  end

  it "serializes with signature when present" do
    block = Anthropic::Content.thinking("Reasoning...", signature: "sig456")
    json = JSON.parse(block.to_json)
    json["type"].as_s.should eq("thinking")
    json["thinking"].as_s.should eq("Reasoning...")
    json["signature"].as_s.should eq("sig456")
  end
end

describe "Request with thinking param" do
  it "accepts thinking config" do
    config = Anthropic::ThinkingConfig.new(budget_tokens: 10000)
    request = Anthropic::Messages::Request.new(
      model: Anthropic::Model.sonnet,
      messages: [Anthropic::Message.user("Hello!")],
      max_tokens: 1024,
      thinking: config
    )
    request.thinking.should eq(config)
  end

  it "omits thinking when nil" do
    request = Anthropic::Messages::Request.new(
      model: Anthropic::Model.sonnet,
      messages: [Anthropic::Message.user("Hello!")],
      max_tokens: 1024
    )
    request.thinking.should be_nil
  end

  it "serializes thinking to JSON" do
    config = Anthropic::ThinkingConfig.new(budget_tokens: 5000)
    request = Anthropic::Messages::Request.new(
      model: Anthropic::Model.sonnet,
      messages: [Anthropic::Message.user("Hello!")],
      max_tokens: 1024,
      thinking: config
    )
    json = JSON.parse(request.to_json)
    json["thinking"]["type"].as_s.should eq("enabled")
    json["thinking"]["budget_tokens"].as_i.should eq(5000)
  end

  it "omits thinking from JSON when nil" do
    request = Anthropic::Messages::Request.new(
      model: Anthropic::Model.sonnet,
      messages: [Anthropic::Message.user("Hello!")],
      max_tokens: 1024
    )
    json = request.to_json
    json.should_not contain("thinking")
  end

  it "copies thinking in with_stream" do
    config = Anthropic::ThinkingConfig.new(budget_tokens: 8000)
    request = Anthropic::Messages::Request.new(
      model: Anthropic::Model.sonnet,
      messages: [Anthropic::Message.user("Hello!")],
      max_tokens: 1024,
      thinking: config
    )
    stream_request = request.with_stream(true)
    stream_request.thinking.should eq(config)
  end
end

describe Anthropic::ResponseThinkingBlock do
  describe "#initialize" do
    it "creates with thinking text" do
      block = Anthropic::ResponseThinkingBlock.new("My reasoning...")
      block.type.should eq("thinking")
      block.thinking.should eq("My reasoning...")
    end

    it "creates with signature" do
      block = Anthropic::ResponseThinkingBlock.new("Reasoning...", signature: "sig789")
      block.signature.should eq("sig789")
    end

    it "handles empty thinking" do
      block = Anthropic::ResponseThinkingBlock.new("")
      block.thinking.should eq("")
    end
  end

  describe "JSON deserialization" do
    it "deserializes from API response format" do
      json = %({"type":"thinking","thinking":"Let me think..."})
      block = Anthropic::ResponseThinkingBlock.from_json(json)
      block.thinking.should eq("Let me think...")
    end

    it "deserializes with signature" do
      json = %({"type":"thinking","thinking":"Reasoning...","signature":"abc123"})
      block = Anthropic::ResponseThinkingBlock.from_json(json)
      block.thinking.should eq("Reasoning...")
      block.signature.should eq("abc123")
    end

    it "roundtrips correctly" do
      original = Anthropic::ResponseThinkingBlock.new("Complex reasoning...", signature: "sig999")
      json = original.to_json
      restored = Anthropic::ResponseThinkingBlock.from_json(json)
      restored.thinking.should eq(original.thinking)
      restored.signature.should eq(original.signature)
    end
  end
end

describe "Response with thinking blocks" do
  it "parses thinking content blocks" do
    json = <<-JSON
      {
        "id": "msg_thinking",
        "type": "message",
        "role": "assistant",
        "content": [
          {"type": "thinking", "thinking": "Let me analyze this..."},
          {"type": "text", "text": "Here's my answer."}
        ],
        "model": "claude-sonnet-4-20250514",
        "stop_reason": "end_turn",
        "stop_sequence": null,
        "usage": {"input_tokens": 10, "output_tokens": 50}
      }
      JSON
    response = Anthropic::Messages::Response.from_json(json)
    response.content.size.should eq(2)

    thinking_block = response.content[0]
    thinking_block.should be_a(Anthropic::ResponseThinkingBlock)
    thinking = thinking_block.as(Anthropic::ResponseThinkingBlock)
    thinking.thinking.should eq("Let me analyze this...")

    text_block = response.content[1]
    text_block.should be_a(Anthropic::ResponseTextBlock)
    text_block.as(Anthropic::ResponseTextBlock).text.should eq("Here's my answer.")
  end

  it "parses thinking block with signature" do
    json = <<-JSON
      {
        "id": "msg_signed",
        "type": "message",
        "role": "assistant",
        "content": [
          {"type": "thinking", "thinking": "Secure reasoning...", "signature": "signed_data_123"}
        ],
        "model": "claude-sonnet-4-20250514",
        "stop_reason": "end_turn",
        "stop_sequence": null,
        "usage": {"input_tokens": 5, "output_tokens": 20}
      }
      JSON
    response = Anthropic::Messages::Response.from_json(json)
    block = response.content.first
    block.should be_a(Anthropic::ResponseThinkingBlock)
    thinking = block.as(Anthropic::ResponseThinkingBlock)
    thinking.signature.should eq("signed_data_123")
  end
end
