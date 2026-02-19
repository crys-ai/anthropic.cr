require "../spec_helper"

describe Anthropic::ToolDefinition do
  describe "#to_json" do
    it "serializes tool definition" do
      schema = JSON.parse(%({"type": "object", "properties": {"query": {"type": "string"}}}))
      tool = Anthropic::ToolDefinition.new(
        name: "search",
        description: "Search the web",
        input_schema: schema,
      )

      json = tool.to_json
      json.should contain("\"name\":\"search\"")
      json.should contain("\"description\":\"Search the web\"")
      json.should contain("\"input_schema\"")
    end

    it "omits description when nil" do
      schema = JSON.parse(%({"type": "object"}))
      tool = Anthropic::ToolDefinition.new(
        name: "simple",
        input_schema: schema,
      )

      json = tool.to_json
      json.should_not contain("\"description\"")
    end
  end
end

describe Anthropic::ToolChoice do
  describe ".auto" do
    it "creates auto choice" do
      choice = Anthropic::ToolChoice.auto
      choice.type.should eq("auto")
      choice.name.should be_nil
    end
  end

  describe ".any" do
    it "creates any choice" do
      choice = Anthropic::ToolChoice.any
      choice.type.should eq("any")
    end
  end

  describe ".tool" do
    it "creates specific tool choice" do
      choice = Anthropic::ToolChoice.tool("search")
      choice.type.should eq("tool")
      choice.name.should eq("search")
    end
  end
end

describe Anthropic::ToolUse do
  describe ".extract_tool_calls" do
    it "extracts tool use blocks from response" do
      # Create a mock response with tool use blocks
      response_json = <<-JSON
        {
          "id": "msg_123",
          "type": "message",
          "role": "assistant",
          "content": [
            {"type": "tool_use", "id": "toolu_1", "name": "search", "input": {"query": "test"}}
          ],
          "model": "claude-sonnet-4-6",
          "stop_reason": "tool_use",
          "usage": {"input_tokens": 10, "output_tokens": 20}
        }
        JSON

      response = Anthropic::Messages::Response.from_json(response_json)
      tool_calls = Anthropic::ToolUse.extract_tool_calls(response)

      tool_calls.size.should eq(1)
      tool_calls[0].name.should eq("search")
    end
  end

  describe ".build_tool_result" do
    it "builds single tool result message" do
      message = Anthropic::ToolUse.build_tool_result("toolu_1", "Result content")

      message.role.should eq(Anthropic::Message::Role::User)
      message.content.size.should eq(1)
    end

    it "builds multiple tool results message" do
      results = [
        {"toolu_1", "Result 1"},
        {"toolu_2", "Result 2"},
      ]
      message = Anthropic::ToolUse.build_tool_result(results)

      message.content.size.should eq(2)
    end
  end

  describe ".has_tool_calls?" do
    it "returns true when tool use blocks present" do
      response_json = <<-JSON
        {
          "id": "msg_123",
          "type": "message",
          "role": "assistant",
          "content": [
            {"type": "tool_use", "id": "toolu_1", "name": "search", "input": {}}
          ],
          "model": "claude-sonnet-4-6",
          "stop_reason": "tool_use",
          "usage": {"input_tokens": 10, "output_tokens": 20}
        }
        JSON

      response = Anthropic::Messages::Response.from_json(response_json)
      Anthropic::ToolUse.has_tool_calls?(response).should be_true
    end

    it "returns false when no tool use blocks" do
      response_json = <<-JSON
        {
          "id": "msg_123",
          "type": "message",
          "role": "assistant",
          "content": [
            {"type": "text", "text": "Hello"}
          ],
          "model": "claude-sonnet-4-6",
          "stop_reason": "end_turn",
          "usage": {"input_tokens": 10, "output_tokens": 20}
        }
        JSON

      response = Anthropic::Messages::Response.from_json(response_json)
      Anthropic::ToolUse.has_tool_calls?(response).should be_false
    end
  end

  describe ".wants_tool_use?" do
    it "returns true when stop_reason is tool_use" do
      response_json = <<-JSON
        {
          "id": "msg_123",
          "type": "message",
          "role": "assistant",
          "content": [],
          "model": "claude-sonnet-4-6",
          "stop_reason": "tool_use",
          "usage": {"input_tokens": 10, "output_tokens": 20}
        }
        JSON

      response = Anthropic::Messages::Response.from_json(response_json)
      Anthropic::ToolUse.wants_tool_use?(response).should be_true
    end

    it "returns false when stop_reason is end_turn" do
      response_json = <<-JSON
        {
          "id": "msg_123",
          "type": "message",
          "role": "assistant",
          "content": [{"type": "text", "text": "Done"}],
          "model": "claude-sonnet-4-6",
          "stop_reason": "end_turn",
          "usage": {"input_tokens": 10, "output_tokens": 20}
        }
        JSON

      response = Anthropic::Messages::Response.from_json(response_json)
      Anthropic::ToolUse.wants_tool_use?(response).should be_false
    end
  end
end
