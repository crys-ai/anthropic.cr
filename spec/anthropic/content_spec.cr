require "../spec_helper"

describe Anthropic::Content do
  describe Anthropic::Content::Type do
    it "has all content types" do
      Anthropic::Content::Type::Text.should be_a(Anthropic::Content::Type)
      Anthropic::Content::Type::Image.should be_a(Anthropic::Content::Type)
      Anthropic::Content::Type::ToolUse.should be_a(Anthropic::Content::Type)
      Anthropic::Content::Type::ToolResult.should be_a(Anthropic::Content::Type)
    end

    it "serializes to snake_case" do
      Anthropic::Content::Type::ToolUse.to_json.should eq(%("tool_use"))
      Anthropic::Content::Type::ToolResult.to_json.should eq(%("tool_result"))
    end
  end

  describe ".text" do
    it "creates a text content block" do
      block = Anthropic::Content.text("Hello!")
      block.should be_a(Anthropic::Content::Block(Anthropic::Content::TextData))
    end

    it "has correct type" do
      block = Anthropic::Content.text("Hello!")
      block.type.should eq(Anthropic::Content::Type::Text)
    end

    it "exposes text data" do
      block = Anthropic::Content.text("Hello!")
      block.data.text.should eq("Hello!")
    end

    it "serializes to JSON" do
      block = Anthropic::Content.text("Hello!")
      json = block.to_json
      json.should eq(%({"type":"text","text":"Hello!"}))
    end

    it "handles empty text" do
      block = Anthropic::Content.text("")
      block.data.text.should eq("")
    end

    it "handles unicode" do
      block = Anthropic::Content.text("Hello 世界! 🌍")
      block.data.text.should eq("Hello 世界! 🌍")
    end

    it "handles multiline text" do
      block = Anthropic::Content.text("Line 1\nLine 2")
      json = JSON.parse(block.to_json)
      json["text"].as_s.should eq("Line 1\nLine 2")
    end
  end

  describe ".image" do
    it "creates an image content block" do
      block = Anthropic::Content.image("image/png", "base64data")
      block.should be_a(Anthropic::Content::Block(Anthropic::Content::ImageData))
    end

    it "has correct type" do
      block = Anthropic::Content.image("image/png", "base64data")
      block.type.should eq(Anthropic::Content::Type::Image)
    end

    it "exposes image data via delegation" do
      block = Anthropic::Content.image("image/png", "base64data")
      block.data.media_type.should eq("image/png")
      block.data.data.should eq("base64data")
    end

    it "serializes to correct JSON structure" do
      block = Anthropic::Content.image("image/jpeg", "abc123")
      json = JSON.parse(block.to_json)

      json["type"].as_s.should eq("image")
      json["source"]["type"].as_s.should eq("base64")
      json["source"]["media_type"].as_s.should eq("image/jpeg")
      json["source"]["data"].as_s.should eq("abc123")
    end

    it "accepts ImageSource directly" do
      source = Anthropic::Content::ImageSource.new("image/gif", "gifdata")
      block = Anthropic::Content.image(source)

      block.data.media_type.should eq("image/gif")
      block.data.data.should eq("gifdata")
    end
  end

  describe Anthropic::Content::Block do
    it "is generic over data type" do
      text_block = Anthropic::Content.text("Hello")
      image_block = Anthropic::Content.image("image/png", "data")

      # Type safety - each block knows its data type
      text_block.data.should be_a(Anthropic::Content::TextData)
      image_block.data.should be_a(Anthropic::Content::ImageData)
    end
  end

  describe "in messages" do
    it "can be used in user messages" do
      contents = [
        Anthropic::Content.text("What's in this image?"),
        Anthropic::Content.image("image/png", "base64data"),
      ] of Anthropic::ContentBlock

      msg = Anthropic::Message.user(contents)
      msg.role.should eq(Anthropic::Message::Role::User)
    end

    it "serializes message with mixed content" do
      contents = [
        Anthropic::Content.text("Describe this:"),
        Anthropic::Content.image("image/png", "abc"),
      ] of Anthropic::ContentBlock

      msg = Anthropic::Message.user(contents)
      json = JSON.parse(msg.to_json)

      json["role"].as_s.should eq("user")
      json["content"].as_a.size.should eq(2)
      json["content"][0]["type"].as_s.should eq("text")
      json["content"][1]["type"].as_s.should eq("image")
    end
  end

  describe ".tool_use" do
    it "creates a tool use content block" do
      input = JSON.parse(%({"query": "test"}))
      block = Anthropic::Content.tool_use("tool_123", "search", input)
      block.should be_a(Anthropic::Content::Block(Anthropic::Content::ToolUseData))
    end

    it "has correct type" do
      input = JSON.parse(%(null))
      block = Anthropic::Content.tool_use("id", "name", input)
      block.type.should eq(Anthropic::Content::Type::ToolUse)
    end

    it "serializes to correct JSON" do
      input = JSON.parse(%({"key": "value"}))
      block = Anthropic::Content.tool_use("tool_1", "get_weather", input)
      json = JSON.parse(block.to_json)

      json["type"].as_s.should eq("tool_use")
      json["id"].as_s.should eq("tool_1")
      json["name"].as_s.should eq("get_weather")
      json["input"]["key"].as_s.should eq("value")
    end
  end

  describe ".tool_result" do
    it "creates a tool result content block" do
      block = Anthropic::Content.tool_result("tool_1", "The weather is sunny")
      block.should be_a(Anthropic::Content::Block(Anthropic::Content::ToolResultData))
    end

    it "has correct type" do
      block = Anthropic::Content.tool_result("tool_1", "result")
      block.type.should eq(Anthropic::Content::Type::ToolResult)
    end

    it "serializes to correct JSON" do
      block = Anthropic::Content.tool_result("tool_1", "42 degrees")
      json = JSON.parse(block.to_json)

      json["type"].as_s.should eq("tool_result")
      json["tool_use_id"].as_s.should eq("tool_1")
      json["content"].as_s.should eq("42 degrees")
    end

    it "serializes is_error when true" do
      block = Anthropic::Content.tool_result("tool_1", "Not found", is_error: true)
      json = JSON.parse(block.to_json)

      json["is_error"].as_bool.should be_true
    end

    it "omits is_error when false" do
      block = Anthropic::Content.tool_result("tool_1", "result")
      json = block.to_json
      json.should_not contain("is_error")
    end
  end
end
