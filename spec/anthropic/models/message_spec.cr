require "../../spec_helper"

describe Anthropic::Message do
  describe ".user" do
    it "creates user message" do
      msg = Anthropic::Message.user("Hello!")
      msg.role.should eq(Anthropic::Message::Role::User)
      msg.content.should eq("Hello!")
    end

    it "handles empty content" do
      msg = Anthropic::Message.user("")
      msg.content.should eq("")
    end

    it "handles multiline content" do
      msg = Anthropic::Message.user("Line 1\nLine 2")
      msg.content.should eq("Line 1\nLine 2")
    end
  end

  describe ".assistant" do
    it "creates assistant message" do
      msg = Anthropic::Message.assistant("Hi!")
      msg.role.should eq(Anthropic::Message::Role::Assistant)
      msg.content.should eq("Hi!")
    end

    it "handles complex responses" do
      content = "Here's a code example:\n```\nputs 'hello'\n```"
      msg = Anthropic::Message.assistant(content)
      msg.content.should eq(content)
    end
  end

  describe "Role enum" do
    it "has user role" do
      Anthropic::Message::Role::User.to_s.should eq("User")
    end

    it "has assistant role" do
      Anthropic::Message::Role::Assistant.to_s.should eq("Assistant")
    end
  end

  describe "JSON" do
    it "serializes role as lowercase" do
      msg = Anthropic::Message.user("Hello!")
      json = msg.to_json
      json.should contain(%("role":"user"))
      json.should contain(%("content":"Hello!"))
    end

    it "serializes assistant role as lowercase" do
      msg = Anthropic::Message.assistant("Hi!")
      json = msg.to_json
      json.should contain(%("role":"assistant"))
    end

    it "handles special characters in content" do
      msg = Anthropic::Message.user("Hello \"world\"!")
      json = msg.to_json
      json.should contain("Hello \\\"world\\\"!")
    end

    it "roundtrips user message" do
      original = Anthropic::Message.user("Test message")
      json = original.to_json
      restored = Anthropic::Message.from_json(json)
      restored.role.should eq(original.role)
      restored.content.should eq(original.content)
    end

    it "roundtrips assistant message" do
      original = Anthropic::Message.assistant("Response text")
      json = original.to_json
      restored = Anthropic::Message.from_json(json)
      restored.role.should eq(original.role)
      restored.content.should eq(original.content)
    end
  end

  describe "content block array parsing" do
    it "parses text content blocks from JSON" do
      json = %({"role":"user","content":[{"type":"text","text":"Hello!"}]})
      msg = Anthropic::Message.from_json(json)
      msg.role.should eq(Anthropic::Message::Role::User)
      msg.content.should be_a(Array(Anthropic::ContentBlock))
      blocks = msg.content.as(Array(Anthropic::ContentBlock))
      blocks.size.should eq(1)
    end

    it "parses multiple text blocks" do
      json = %({"role":"assistant","content":[{"type":"text","text":"Part 1"},{"type":"text","text":"Part 2"}]})
      msg = Anthropic::Message.from_json(json)
      blocks = msg.content.as(Array(Anthropic::ContentBlock))
      blocks.size.should eq(2)
    end

    it "parses tool_use content blocks" do
      json = %({"role":"assistant","content":[{"type":"tool_use","id":"tool_1","name":"search","input":{"q":"test"}}]})
      msg = Anthropic::Message.from_json(json)
      blocks = msg.content.as(Array(Anthropic::ContentBlock))
      blocks.size.should eq(1)
      blocks.first.type.should eq(Anthropic::Content::Type::ToolUse)
    end

    it "parses tool_result content blocks" do
      json = %({"role":"user","content":[{"type":"tool_result","tool_use_id":"tool_1","content":"42","is_error":false}]})
      msg = Anthropic::Message.from_json(json)
      blocks = msg.content.as(Array(Anthropic::ContentBlock))
      blocks.size.should eq(1)
      blocks.first.type.should eq(Anthropic::Content::Type::ToolResult)
    end

    it "parses unknown content block types without crashing" do
      json = %({"role":"assistant","content":[{"type":"thinking","thinking":"I need to...","signature":"abc123"}]})
      msg = Anthropic::Message.from_json(json)
      blocks = msg.content.as(Array(Anthropic::ContentBlock))
      blocks.size.should eq(1)
      block = blocks.first
      block.data.should be_a(Anthropic::Content::UnknownData)
      unknown = block.data.as(Anthropic::Content::UnknownData)
      unknown.type_string.should eq("thinking")
      unknown.raw["thinking"].as_s.should eq("I need to...")
    end

    it "parses mixed known and unknown content blocks" do
      json = %({"role":"assistant","content":[{"type":"text","text":"Hello"},{"type":"server_tool_use","id":"st_1","name":"web_search","input":{"q":"test"}}]})
      msg = Anthropic::Message.from_json(json)
      blocks = msg.content.as(Array(Anthropic::ContentBlock))
      blocks.size.should eq(2)
      blocks[0].data.should be_a(Anthropic::Content::TextData)
      blocks[1].data.should be_a(Anthropic::Content::UnknownData)
    end

    it "parses tool_result with array content" do
      json = %({"role":"user","content":[{"type":"tool_result","tool_use_id":"tool_1","content":[{"type":"text","text":"result"}],"is_error":false}]})
      msg = Anthropic::Message.from_json(json)
      blocks = msg.content.as(Array(Anthropic::ContentBlock))
      blocks.size.should eq(1)
    end
  end

  describe "unknown content roundtrip" do
    it "preserves unknown type through serialization roundtrip" do
      original_json = %({"role":"assistant","content":[{"type":"thinking","thinking":"I need to...","signature":"abc123"}]})
      msg = Anthropic::Message.from_json(original_json)
      blocks = msg.content.as(Array(Anthropic::ContentBlock))
      blocks.size.should eq(1)

      block = blocks.first
      block.data.should be_a(Anthropic::Content::UnknownData)
      unknown = block.data.as(Anthropic::Content::UnknownData)
      unknown.type_string.should eq("thinking")
      unknown.raw["thinking"].as_s.should eq("I need to...")
      unknown.raw["signature"].as_s.should eq("abc123")

      # Roundtrip through JSON serialization
      serialized = msg.to_json
      serialized.should contain(%("type":"thinking"))
      serialized.should contain(%("thinking":"I need to..."))
      serialized.should contain(%("signature":"abc123"))

      # Parse again and verify data preserved
      restored = Anthropic::Message.from_json(serialized)
      restored_blocks = restored.content.as(Array(Anthropic::ContentBlock))
      restored_blocks.size.should eq(1)
      restored_unknown = restored_blocks.first.data.as(Anthropic::Content::UnknownData)
      restored_unknown.type_string.should eq("thinking")
      restored_unknown.raw["thinking"].as_s.should eq("I need to...")
      restored_unknown.raw["signature"].as_s.should eq("abc123")
    end

    it "preserves unknown type with complex nested data" do
      original_json = %({"role":"assistant","content":[{"type":"citation","text":"Hello","source":{"type":"file","file_id":"file_123","start":0,"end":5}}]})
      msg = Anthropic::Message.from_json(original_json)
      blocks = msg.content.as(Array(Anthropic::ContentBlock))
      blocks.size.should eq(1)

      unknown = blocks.first.data.as(Anthropic::Content::UnknownData)
      unknown.type_string.should eq("citation")

      # Verify roundtrip
      serialized = msg.to_json
      serialized.should contain(%("type":"citation"))
      serialized.should contain(%("text":"Hello"))

      restored = Anthropic::Message.from_json(serialized)
      restored_unknown = restored.content.as(Array(Anthropic::ContentBlock)).first.data.as(Anthropic::Content::UnknownData)
      restored_unknown.type_string.should eq("citation")
      restored_unknown.raw["text"].as_s.should eq("Hello")
      restored_unknown.raw["source"]["file_id"].as_s.should eq("file_123")
    end

    it "handles unknown block without type field (defensive)" do
      # Edge case: malformed JSON without type field
      original_json = %({"role":"assistant","content":[{"custom":"value"}]})
      msg = Anthropic::Message.from_json(original_json)
      blocks = msg.content.as(Array(Anthropic::ContentBlock))
      blocks.size.should eq(1)

      unknown = blocks.first.data.as(Anthropic::Content::UnknownData)
      unknown.type_string.should eq("") # Empty string when no type
      unknown.raw["custom"].as_s.should eq("value")
    end
  end

  describe "tool_result content array preservation" do
    it "roundtrips tool_result with string content" do
      json = %({"role":"user","content":[{"type":"tool_result","tool_use_id":"tool_1","content":"42"}]})
      msg = Anthropic::Message.from_json(json)
      blocks = msg.content.as(Array(Anthropic::ContentBlock))
      blocks.size.should eq(1)

      tool_result = blocks.first.data.as(Anthropic::Content::ToolResultData)
      tool_result.tool_use_id.should eq("tool_1")
      tool_result.content.should eq("42")
      tool_result.is_error?.should be_false

      # Roundtrip
      serialized = msg.to_json
      restored = Anthropic::Message.from_json(serialized)
      restored_tool = restored.content.as(Array(Anthropic::ContentBlock)).first.data.as(Anthropic::Content::ToolResultData)
      restored_tool.tool_use_id.should eq("tool_1")
      restored_tool.content.should eq("42")
    end

    it "roundtrips tool_result with array content (text + image blocks)" do
      json = %({"role":"user","content":[{"type":"tool_result","tool_use_id":"tool_2","content":[{"type":"text","text":"Here is the result"},{"type":"image","source":{"type":"base64","media_type":"image/png","data":"iVBOR..."}}]}]})
      msg = Anthropic::Message.from_json(json)
      blocks = msg.content.as(Array(Anthropic::ContentBlock))
      blocks.size.should eq(1)

      tool_result = blocks.first.data.as(Anthropic::Content::ToolResultData)
      tool_result.tool_use_id.should eq("tool_2")
      content_arr = tool_result.content.as(Array(JSON::Any))
      content_arr.size.should eq(2)
      content_arr[0]["type"].as_s.should eq("text")
      content_arr[0]["text"].as_s.should eq("Here is the result")
      content_arr[1]["type"].as_s.should eq("image")
      content_arr[1]["source"]["media_type"].as_s.should eq("image/png")

      # Roundtrip
      serialized = msg.to_json
      serialized.should contain(%("tool_use_id":"tool_2"))
      serialized.should contain(%("type":"text"))
      serialized.should contain(%("Here is the result"))
      serialized.should contain(%("image/png"))

      restored = Anthropic::Message.from_json(serialized)
      restored_tool = restored.content.as(Array(Anthropic::ContentBlock)).first.data.as(Anthropic::Content::ToolResultData)
      restored_content = restored_tool.content.as(Array(JSON::Any))
      restored_content.size.should eq(2)
      restored_content[0]["text"].as_s.should eq("Here is the result")
      restored_content[1]["source"]["media_type"].as_s.should eq("image/png")
    end

    it "roundtrips tool_result with nil content (defaults to empty string)" do
      json = %({"role":"user","content":[{"type":"tool_result","tool_use_id":"tool_3"}]})
      msg = Anthropic::Message.from_json(json)
      blocks = msg.content.as(Array(Anthropic::ContentBlock))
      tool_result = blocks.first.data.as(Anthropic::Content::ToolResultData)
      tool_result.content.should eq("")
    end

    it "preserves is_error flag with array content" do
      json = %({"role":"user","content":[{"type":"tool_result","tool_use_id":"tool_4","content":[{"type":"text","text":"Error details"}],"is_error":true}]})
      msg = Anthropic::Message.from_json(json)
      tool_result = msg.content.as(Array(Anthropic::ContentBlock)).first.data.as(Anthropic::Content::ToolResultData)
      tool_result.is_error?.should be_true
      tool_result.content.as(Array(JSON::Any)).size.should eq(1)

      # Roundtrip preserves is_error
      serialized = msg.to_json
      serialized.should contain(%("is_error":true))
      restored_tool = Anthropic::Message.from_json(serialized).content.as(Array(Anthropic::ContentBlock)).first.data.as(Anthropic::Content::ToolResultData)
      restored_tool.is_error?.should be_true
    end

    it "handles mixed content types in a message with tool_result arrays" do
      json = %({"role":"user","content":[{"type":"text","text":"Here is the result:"},{"type":"tool_result","tool_use_id":"tool_5","content":[{"type":"text","text":"computed value: 42"}]}]})
      msg = Anthropic::Message.from_json(json)
      blocks = msg.content.as(Array(Anthropic::ContentBlock))
      blocks.size.should eq(2)

      blocks[0].data.should be_a(Anthropic::Content::TextData)
      blocks[0].data.as(Anthropic::Content::TextData).text.should eq("Here is the result:")

      blocks[1].data.should be_a(Anthropic::Content::ToolResultData)
      tool_result = blocks[1].data.as(Anthropic::Content::ToolResultData)
      tool_result.content.as(Array(JSON::Any)).first["text"].as_s.should eq("computed value: 42")
    end
  end
end
