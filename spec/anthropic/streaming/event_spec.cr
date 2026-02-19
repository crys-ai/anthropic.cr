require "../../spec_helper"

describe Anthropic::StreamEvent do
  describe ".parse" do
    it "parses message_start" do
      json = %({"type":"message_start","message":{"id":"msg-123","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-5-20250929","stop_reason":null,"usage":{"input_tokens":10,"output_tokens":1}}})
      event = Anthropic::StreamEvent.parse("message_start", json)
      event.should be_a(Anthropic::StreamEvent::MessageStart)
      event.type.should eq "message_start"

      if event.is_a?(Anthropic::StreamEvent::MessageStart)
        event.message.id.should eq "msg-123"
        event.message.model.should eq "claude-sonnet-4-5-20250929"
        event.message.role.should eq "assistant"
      end
    end

    it "parses content_block_start" do
      json = %({"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}})
      event = Anthropic::StreamEvent.parse("content_block_start", json)
      event.should be_a(Anthropic::StreamEvent::ContentBlockStart)

      if event.is_a?(Anthropic::StreamEvent::ContentBlockStart)
        event.index.should eq 0
        event.content_block.type.should eq "text"
      end
    end

    it "parses content_block_delta with text" do
      json = %({"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}})
      event = Anthropic::StreamEvent.parse("content_block_delta", json)
      event.should be_a(Anthropic::StreamEvent::ContentBlockDelta)

      if event.is_a?(Anthropic::StreamEvent::ContentBlockDelta)
        event.index.should eq 0
        event.delta.type.should eq "text_delta"
        event.delta.text.should eq "Hello"
      end
    end

    it "parses content_block_delta with partial_json" do
      json = %({"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\\"key\\""}})
      event = Anthropic::StreamEvent.parse("content_block_delta", json)

      if event.is_a?(Anthropic::StreamEvent::ContentBlockDelta)
        event.delta.type.should eq "input_json_delta"
        event.delta.partial_json.should eq %({"key")
      end
    end

    it "parses content_block_stop" do
      json = %({"type":"content_block_stop","index":0})
      event = Anthropic::StreamEvent.parse("content_block_stop", json)
      event.should be_a(Anthropic::StreamEvent::ContentBlockStop)

      if event.is_a?(Anthropic::StreamEvent::ContentBlockStop)
        event.index.should eq 0
      end
    end

    it "parses message_delta" do
      json = %({"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"input_tokens":0,"output_tokens":5}})
      event = Anthropic::StreamEvent.parse("message_delta", json)
      event.should be_a(Anthropic::StreamEvent::MessageDelta)

      if event.is_a?(Anthropic::StreamEvent::MessageDelta)
        event.delta.stop_reason.should eq "end_turn"
        event.usage.should_not be_nil
      end
    end

    it "parses message_stop" do
      json = %({"type":"message_stop"})
      event = Anthropic::StreamEvent.parse("message_stop", json)
      event.should be_a(Anthropic::StreamEvent::MessageStop)
    end

    it "parses ping" do
      json = %({"type":"ping"})
      event = Anthropic::StreamEvent.parse("ping", json)
      event.should be_a(Anthropic::StreamEvent::Ping)
    end

    it "parses error" do
      json = %({"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}})
      event = Anthropic::StreamEvent.parse("error", json)
      event.should be_a(Anthropic::StreamEvent::Error)

      if event.is_a?(Anthropic::StreamEvent::Error)
        event.error.type.should eq "overloaded_error"
        event.error.message.should eq "Overloaded"
      end
    end

    it "parses unknown events" do
      json = %({"type":"future_event","foo":"bar"})
      event = Anthropic::StreamEvent.parse("future_event", json)
      event.should be_a(Anthropic::UnknownStreamEvent)
    end

    it "parses unknown events with non-JSON text" do
      text = "plain text data"
      event = Anthropic::StreamEvent.parse("future_event", text)
      event.should be_a(Anthropic::UnknownStreamEvent)

      if event.is_a?(Anthropic::UnknownStreamEvent)
        event.raw.as_s.should eq "plain text data"
      end
    end

    it "parses unknown events with empty string" do
      event = Anthropic::StreamEvent.parse("future_event", "")
      event.should be_a(Anthropic::UnknownStreamEvent)

      if event.is_a?(Anthropic::UnknownStreamEvent)
        event.raw.as_s.should eq ""
      end
    end
  end
end
