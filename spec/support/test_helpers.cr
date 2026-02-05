# Test helper classes for spec files.
module TestHelpers
  SAMPLE_RESPONSE_JSON = <<-JSON
    {
      "id": "msg_01XFDUDYJgAACzvnptvVoYEL",
      "type": "message",
      "role": "assistant",
      "content": [{"type": "text", "text": "Hello! How can I help?"}],
      "model": "claude-sonnet-4-20250514",
      "stop_reason": "end_turn",
      "stop_sequence": null,
      "usage": {"input_tokens": 25, "output_tokens": 20}
    }
    JSON

  def self.with_env(key : String, value : String?, &) : Nil
    old = ENV[key]?
    if value
      ENV[key] = value
    else
      ENV.delete(key)
    end
    yield
  ensure
    if old
      ENV[key] = old
    else
      ENV.delete(key)
    end
  end
end
