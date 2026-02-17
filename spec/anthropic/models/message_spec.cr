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
end
