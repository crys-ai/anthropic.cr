# Shared test helpers, fixtures, and stub structs for specs.
module TestHelpers
  API_URL = "https://api.anthropic.com/v1/messages"

  # Standard successful API response JSON.
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

  # Builds a valid API response JSON with customizable text.
  def self.response_json(
    text : String = "Hello!",
    id : String = "msg_test_123",
    model : String = "claude-sonnet-4-5-20251101",
    stop_reason : String = "end_turn",
    input_tokens : Int32 = 10,
    output_tokens : Int32 = 20,
  ) : String
    <<-JSON
      {
        "id": "#{id}",
        "type": "message",
        "role": "assistant",
        "content": [{"type": "text", "text": #{text.to_json}}],
        "model": "#{model}",
        "stop_reason": "#{stop_reason}",
        "stop_sequence": null,
        "usage": {"input_tokens": #{input_tokens}, "output_tokens": #{output_tokens}}
      }
      JSON
  end

  # Builds an API error response JSON.
  def self.error_json(type : String, message : String) : String
    <<-JSON
      {
        "type": "error",
        "error": {"type": "#{type}", "message": #{message.to_json}}
      }
      JSON
  end

  # Stubs a successful POST to the messages API.
  def self.stub_messages(
    text : String = "Hello!",
    id : String = "msg_test_123",
    model : String = "claude-sonnet-4-5-20251101",
    stop_reason : String = "end_turn",
    input_tokens : Int32 = 10,
    output_tokens : Int32 = 20,
  ) : Nil
    WebMock.stub(:post, API_URL).to_return(
      status: 200,
      body: response_json(text: text, id: id, model: model, stop_reason: stop_reason, input_tokens: input_tokens, output_tokens: output_tokens),
      headers: {"Content-Type" => "application/json"},
    )
  end

  # Stubs an error POST to the messages API.
  def self.stub_error(status : Int32, type : String, message : String) : Nil
    WebMock.stub(:post, API_URL).to_return(
      status: status,
      body: error_json(type, message),
      headers: {"Content-Type" => "application/json"},
    )
  end

  # Temporarily sets an environment variable for the duration of the block.
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

  # Creates a test client with a stubbed API key.
  def self.test_client(api_key : String = "sk-ant-test-key") : Anthropic::Client
    Anthropic::Client.new(api_key: api_key)
  end
end

# Test implementation of Data protocol for spec purposes.
struct TestContentData
  include Anthropic::Content::Data

  getter value : String

  def initialize(@value : String)
  end

  def content_type : Anthropic::Content::Type
    Anthropic::Content::Type::Text
  end

  def to_content_json(json : JSON::Builder) : Nil
    json.field "test_value", @value
  end
end
