require "json"

abstract struct Anthropic::StreamEvent
  include JSON::Serializable

  getter type : String

  def self.parse(type : String, json : String) : StreamEvent
    case type
    when "message_start"       then MessageStart.from_json(json)
    when "content_block_start" then ContentBlockStart.from_json(json)
    when "content_block_delta" then ContentBlockDelta.from_json(json)
    when "content_block_stop"  then ContentBlockStop.from_json(json)
    when "message_delta"       then MessageDelta.from_json(json)
    when "message_stop"        then MessageStop.from_json(json)
    when "ping"                then Ping.from_json(json)
    when "error"               then Error.from_json(json)
    else                            UnknownStreamEvent.new(type, JSON.parse(json))
    end
  end
end

struct Anthropic::UnknownStreamEvent < Anthropic::StreamEvent
  include JSON::Serializable
  getter raw : JSON::Any

  def initialize(@type = "unknown", @raw = JSON::Any.new({} of String => JSON::Any))
  end
end

struct Anthropic::StreamEvent::MessageStart < Anthropic::StreamEvent
  include JSON::Serializable
  getter message : ResponseMessage

  struct ResponseMessage
    include JSON::Serializable
    getter id : String
    getter type : String
    getter role : String
    getter content : Array(JSON::Any)?
    getter model : String
    getter stop_reason : String?
    getter usage : Usage?
  end
end

struct Anthropic::StreamEvent::ContentBlockStart < Anthropic::StreamEvent
  include JSON::Serializable
  getter index : Int64
  getter content_block : ContentBlock

  struct ContentBlock
    include JSON::Serializable
    getter type : String
    getter text : String?
  end
end

struct Anthropic::StreamEvent::ContentBlockDelta < Anthropic::StreamEvent
  include JSON::Serializable
  getter index : Int64
  getter delta : Delta

  struct Delta
    include JSON::Serializable
    getter type : String
    getter text : String?
    getter partial_json : String? # for tool use streaming
    getter thinking : String?     # for extended thinking
  end
end

struct Anthropic::StreamEvent::ContentBlockStop < Anthropic::StreamEvent
  include JSON::Serializable
  getter index : Int64
end

struct Anthropic::StreamEvent::MessageDelta < Anthropic::StreamEvent
  include JSON::Serializable
  getter delta : Delta
  getter usage : Usage?

  struct Delta
    include JSON::Serializable
    getter stop_reason : String?
  end
end

struct Anthropic::StreamEvent::MessageStop < Anthropic::StreamEvent
  include JSON::Serializable
end

struct Anthropic::StreamEvent::Ping < Anthropic::StreamEvent
  include JSON::Serializable
  # Keep-alive event, no additional fields
end

struct Anthropic::StreamEvent::Error < Anthropic::StreamEvent
  include JSON::Serializable
  getter error : ErrorInfo

  struct ErrorInfo
    include JSON::Serializable
    getter type : String
    getter message : String
  end
end
