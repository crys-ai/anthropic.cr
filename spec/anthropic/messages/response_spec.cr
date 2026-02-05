require "../../spec_helper"

describe Anthropic::Messages::Response do
  describe "JSON" do
    it "parses complete response" do
      response = Anthropic::Messages::Response.from_json(TestHelpers::SAMPLE_RESPONSE_JSON)
      response.id.should eq("msg_01XFDUDYJgAACzvnptvVoYEL")
      response.type.should eq("message")
      response.role.should eq(Anthropic::Message::Role::Assistant)
      response.model.should eq("claude-sonnet-4-20250514")
      response.stop_reason.should eq(Anthropic::Messages::Response::StopReason::EndTurn)
      response.stop_sequence.should be_nil
    end

    it "parses content blocks" do
      response = Anthropic::Messages::Response.from_json(TestHelpers::SAMPLE_RESPONSE_JSON)
      response.content.size.should eq(1)
      response.content.first.text.should eq("Hello! How can I help?")
    end

    it "parses usage" do
      response = Anthropic::Messages::Response.from_json(TestHelpers::SAMPLE_RESPONSE_JSON)
      response.usage.input_tokens.should eq(25)
      response.usage.output_tokens.should eq(20)
    end

    it "parses multiple content blocks" do
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
      response.content[0].text.should eq("First part.")
      response.content[1].text.should eq(" Second part.")
    end
  end

  describe "#text" do
    it "concatenates content" do
      response = Anthropic::Messages::Response.from_json(TestHelpers::SAMPLE_RESPONSE_JSON)
      response.text.should eq("Hello! How can I help?")
    end

    it "concatenates multiple content blocks" do
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
  end

  describe "StopReason" do
    it "parses end_turn" do
      json = TestHelpers::SAMPLE_RESPONSE_JSON.gsub("end_turn", "end_turn")
      response = Anthropic::Messages::Response.from_json(json)
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
  end
end
