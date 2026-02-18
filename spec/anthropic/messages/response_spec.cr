require "../../spec_helper"

describe Anthropic::Messages::Response do
  describe "JSON" do
    it "parses complete response" do
      response = Anthropic::Messages::Response.from_json(TestHelpers::SAMPLE_RESPONSE_JSON)
      response.id.should eq("msg_01XFDUDYJgAACzvnptvVoYEL")
      response.type.should eq("message")
      response.role.should eq("assistant")
      response.model.should eq("claude-sonnet-4-20250514")
      response.stop_reason.should eq(Anthropic::Messages::Response::StopReason::EndTurn)
      response.stop_sequence.should be_nil
    end

    it "parses text content blocks" do
      response = Anthropic::Messages::Response.from_json(TestHelpers::SAMPLE_RESPONSE_JSON)
      response.content.size.should eq(1)
      block = response.content.first
      block.should be_a(Anthropic::ResponseTextBlock)
      block.as(Anthropic::ResponseTextBlock).text.should eq("Hello! How can I help?")
    end

    it "parses usage" do
      response = Anthropic::Messages::Response.from_json(TestHelpers::SAMPLE_RESPONSE_JSON)
      response.usage.input_tokens.should eq(25)
      response.usage.output_tokens.should eq(20)
    end

    it "parses multiple text content blocks" do
      json = <<-JSON
        {
          "id": "msg_test",
          "type": "message",
          "role": "assistant",
          "content": [
            {"type": "text", "text": "First part."},
            {"type": "text", "text": " Second part."}
          ],
          "model": "claude-sonnet-4-20250514",
          "stop_reason": "end_turn",
          "stop_sequence": null,
          "usage": {"input_tokens": 10, "output_tokens": 15}
        }
        JSON
      response = Anthropic::Messages::Response.from_json(json)
      response.content.size.should eq(2)
      response.content[0].as(Anthropic::ResponseTextBlock).text.should eq("First part.")
      response.content[1].as(Anthropic::ResponseTextBlock).text.should eq(" Second part.")
    end

    it "parses tool_use content blocks" do
      json = <<-JSON
        {
          "id": "msg_tool",
          "type": "message",
          "role": "assistant",
          "content": [
            {
              "type": "tool_use",
              "id": "toolu_01A09q90qw90lq917835lqs136",
              "name": "get_weather",
              "input": {"location": "San Francisco, CA"}
            }
          ],
          "model": "claude-sonnet-4-20250514",
          "stop_reason": "tool_use",
          "stop_sequence": null,
          "usage": {"input_tokens": 50, "output_tokens": 30}
        }
        JSON
      response = Anthropic::Messages::Response.from_json(json)
      response.content.size.should eq(1)
      block = response.content.first
      block.should be_a(Anthropic::ResponseToolUseBlock)
      tool_block = block.as(Anthropic::ResponseToolUseBlock)
      tool_block.id.should eq("toolu_01A09q90qw90lq917835lqs136")
      tool_block.name.should eq("get_weather")
      tool_block.input["location"].as_s.should eq("San Francisco, CA")
    end

    it "parses mixed text and tool_use content blocks" do
      json = <<-JSON
        {
          "id": "msg_mixed",
          "type": "message",
          "role": "assistant",
          "content": [
            {"type": "text", "text": "I'll check the weather."},
            {
              "type": "tool_use",
              "id": "toolu_abc123",
              "name": "get_weather",
              "input": {"location": "NYC"}
            }
          ],
          "model": "claude-sonnet-4-20250514",
          "stop_reason": "tool_use",
          "stop_sequence": null,
          "usage": {"input_tokens": 30, "output_tokens": 40}
        }
        JSON
      response = Anthropic::Messages::Response.from_json(json)
      response.content.size.should eq(2)
      response.content[0].should be_a(Anthropic::ResponseTextBlock)
      response.content[1].should be_a(Anthropic::ResponseToolUseBlock)
    end

    it "preserves unknown content blocks for forward compatibility" do
      json = <<-JSON
        {
          "id": "msg_unknown",
          "type": "message",
          "role": "assistant",
          "content": [
            {"type": "text", "text": "Known text."},
            {"type": "thinking", "thinking": "internal reasoning payload"}
          ],
          "model": "claude-sonnet-4-20250514",
          "stop_reason": "end_turn",
          "stop_sequence": null,
          "usage": {"input_tokens": 10, "output_tokens": 15}
        }
        JSON
      response = Anthropic::Messages::Response.from_json(json)
      response.content.size.should eq(2)
      response.content[0].should be_a(Anthropic::ResponseTextBlock)
      unknown = response.content[1]
      unknown.should be_a(Anthropic::ResponseUnknownBlock)
      unknown_block = unknown.as(Anthropic::ResponseUnknownBlock)
      unknown_block.type.should eq("thinking")
      unknown_block.raw["thinking"].as_s.should eq("internal reasoning payload")
    end

    it "roundtrips unknown content blocks through to_json and from_json" do
      json = <<-JSON
        {
          "id": "msg_unknown_roundtrip",
          "type": "message",
          "role": "assistant",
          "content": [
            {"type": "text", "text": "Known text."},
            {"type": "thinking", "thinking": "internal reasoning payload"}
          ],
          "model": "claude-sonnet-4-20250514",
          "stop_reason": "end_turn",
          "stop_sequence": null,
          "usage": {"input_tokens": 10, "output_tokens": 15}
        }
        JSON

      original = Anthropic::Messages::Response.from_json(json)
      restored = Anthropic::Messages::Response.from_json(original.to_json)

      restored.content.size.should eq(2)
      restored.content[0].should be_a(Anthropic::ResponseTextBlock)
      restored_unknown = restored.content[1]
      restored_unknown.should be_a(Anthropic::ResponseUnknownBlock)
      restored_unknown_block = restored_unknown.as(Anthropic::ResponseUnknownBlock)
      restored_unknown_block.type.should eq("thinking")
      restored_unknown_block.raw["thinking"].as_s.should eq("internal reasoning payload")
    end
  end

  describe "#text" do
    it "concatenates text content" do
      response = Anthropic::Messages::Response.from_json(TestHelpers::SAMPLE_RESPONSE_JSON)
      response.text.should eq("Hello! How can I help?")
    end

    it "concatenates multiple text content blocks" do
      json = <<-JSON
        {
          "id": "msg_test",
          "type": "message",
          "role": "assistant",
          "content": [
            {"type": "text", "text": "Hello "},
            {"type": "text", "text": "world!"}
          ],
          "model": "claude-sonnet-4-20250514",
          "stop_reason": "end_turn",
          "stop_sequence": null,
          "usage": {"input_tokens": 10, "output_tokens": 15}
        }
        JSON
      response = Anthropic::Messages::Response.from_json(json)
      response.text.should eq("Hello world!")
    end

    it "returns empty string for empty content" do
      json = <<-JSON
        {
          "id": "msg_test",
          "type": "message",
          "role": "assistant",
          "content": [],
          "model": "claude-sonnet-4-20250514",
          "stop_reason": "end_turn",
          "stop_sequence": null,
          "usage": {"input_tokens": 10, "output_tokens": 0}
        }
        JSON
      response = Anthropic::Messages::Response.from_json(json)
      response.text.should eq("")
    end

    it "skips non-text blocks when concatenating" do
      json = <<-JSON
        {
          "id": "msg_test",
          "type": "message",
          "role": "assistant",
          "content": [
            {"type": "text", "text": "Here is the result: "},
            {"type": "tool_use", "id": "toolu_1", "name": "calc", "input": {"x": 1}}
          ],
          "model": "claude-sonnet-4-20250514",
          "stop_reason": "tool_use",
          "stop_sequence": null,
          "usage": {"input_tokens": 10, "output_tokens": 15}
        }
        JSON
      response = Anthropic::Messages::Response.from_json(json)
      response.text.should eq("Here is the result: ")
    end
  end

  describe "#tool_use_blocks" do
    it "returns tool use blocks" do
      json = <<-JSON
        {
          "id": "msg_test",
          "type": "message",
          "role": "assistant",
          "content": [
            {"type": "text", "text": "Let me check."},
            {"type": "tool_use", "id": "toolu_1", "name": "search", "input": {"q": "test"}},
            {"type": "tool_use", "id": "toolu_2", "name": "calc", "input": {"x": 42}}
          ],
          "model": "claude-sonnet-4-20250514",
          "stop_reason": "tool_use",
          "stop_sequence": null,
          "usage": {"input_tokens": 10, "output_tokens": 30}
        }
        JSON
      response = Anthropic::Messages::Response.from_json(json)
      tool_blocks = response.tool_use_blocks
      tool_blocks.size.should eq(2)
      tool_blocks[0].name.should eq("search")
      tool_blocks[1].name.should eq("calc")
    end

    it "returns empty array when no tool use blocks" do
      response = Anthropic::Messages::Response.from_json(TestHelpers::SAMPLE_RESPONSE_JSON)
      response.tool_use_blocks.should be_empty
    end
  end

  describe "StopReason" do
    it "parses end_turn" do
      response = Anthropic::Messages::Response.from_json(TestHelpers::SAMPLE_RESPONSE_JSON)
      response.stop_reason.should eq(Anthropic::Messages::Response::StopReason::EndTurn)
    end

    it "parses max_tokens" do
      json = TestHelpers::SAMPLE_RESPONSE_JSON.gsub("end_turn", "max_tokens")
      response = Anthropic::Messages::Response.from_json(json)
      response.stop_reason.should eq(Anthropic::Messages::Response::StopReason::MaxTokens)
    end

    it "parses stop_sequence" do
      json = TestHelpers::SAMPLE_RESPONSE_JSON.gsub("end_turn", "stop_sequence")
      response = Anthropic::Messages::Response.from_json(json)
      response.stop_reason.should eq(Anthropic::Messages::Response::StopReason::StopSequence)
    end

    it "parses tool_use" do
      json = TestHelpers::SAMPLE_RESPONSE_JSON.gsub("end_turn", "tool_use")
      response = Anthropic::Messages::Response.from_json(json)
      response.stop_reason.should eq(Anthropic::Messages::Response::StopReason::ToolUse)
    end

    it "parses null stop_reason" do
      json = TestHelpers::SAMPLE_RESPONSE_JSON.gsub(%("stop_reason": "end_turn"), %("stop_reason": null))
      response = Anthropic::Messages::Response.from_json(json)
      response.stop_reason.should be_nil
    end

    it "returns nil for unknown stop_reason values" do
      json = TestHelpers::SAMPLE_RESPONSE_JSON.gsub(%("stop_reason": "end_turn"), %("stop_reason": "future_stop_reason"))
      response = Anthropic::Messages::Response.from_json(json)
      response.stop_reason.should be_nil
    end

    it "still parses all known stop_reason values" do
      known_reasons = ["end_turn", "max_tokens", "stop_sequence", "tool_use"]
      expected = [
        Anthropic::Messages::Response::StopReason::EndTurn,
        Anthropic::Messages::Response::StopReason::MaxTokens,
        Anthropic::Messages::Response::StopReason::StopSequence,
        Anthropic::Messages::Response::StopReason::ToolUse,
      ]

      known_reasons.each_with_index do |reason, i|
        json = TestHelpers::SAMPLE_RESPONSE_JSON.gsub(%("stop_reason": "end_turn"), %("stop_reason": "#{reason}"))
        response = Anthropic::Messages::Response.from_json(json)
        response.stop_reason.should eq(expected[i])
      end
    end
  end

  describe "role" do
    it "parses assistant role" do
      response = Anthropic::Messages::Response.from_json(TestHelpers::SAMPLE_RESPONSE_JSON)
      response.role.should eq("assistant")
    end

    it "handles unknown role values without crashing" do
      json = TestHelpers::SAMPLE_RESPONSE_JSON.gsub(%("role": "assistant"), %("role": "future_role"))
      response = Anthropic::Messages::Response.from_json(json)
      response.role.should eq("future_role")
    end
  end

  describe "#role_enum" do
    it "returns Role::Assistant for assistant role" do
      response = Anthropic::Messages::Response.from_json(TestHelpers::SAMPLE_RESPONSE_JSON)
      response.role_enum.should eq(Anthropic::Message::Role::Assistant)
    end

    it "returns Role::User for user role" do
      json = TestHelpers::SAMPLE_RESPONSE_JSON.gsub(%("role": "assistant"), %("role": "user"))
      response = Anthropic::Messages::Response.from_json(json)
      response.role_enum.should eq(Anthropic::Message::Role::User)
    end

    it "returns nil for unknown role values (forward compatibility)" do
      json = TestHelpers::SAMPLE_RESPONSE_JSON.gsub(%("role": "assistant"), %("role": "future_role"))
      response = Anthropic::Messages::Response.from_json(json)
      response.role_enum.should be_nil
    end

    it "handles case variations for assistant" do
      json = TestHelpers::SAMPLE_RESPONSE_JSON.gsub(%("role": "assistant"), %("role": "Assistant"))
      response = Anthropic::Messages::Response.from_json(json)
      response.role_enum.should eq(Anthropic::Message::Role::Assistant)
    end

    it "handles case variations for user" do
      json = TestHelpers::SAMPLE_RESPONSE_JSON.gsub(%("role": "assistant"), %("role": "USER"))
      response = Anthropic::Messages::Response.from_json(json)
      response.role_enum.should eq(Anthropic::Message::Role::User)
    end
  end
end
