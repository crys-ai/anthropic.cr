require "json"

struct Anthropic::Message
  enum Role
    User
    Assistant

    def to_json(json : JSON::Builder) : Nil
      json.string(to_s.downcase)
    end
  end

  getter role : Role
  getter content : String | Array(ContentBlock)

  def initialize(@role : Role, @content : String | Array(ContentBlock))
  end

  # Creates a user message with text content.
  def self.user(content : String) : Message
    new(Role::User, content)
  end

  # Creates a user message with content blocks (for images, tool use, etc).
  def self.user(content : Array(ContentBlock)) : Message
    new(Role::User, content)
  end

  # Creates an assistant message with text content.
  def self.assistant(content : String) : Message
    new(Role::Assistant, content)
  end

  def to_json(json : JSON::Builder) : Nil
    json.object do
      json.field "role", @role
      json.field "content", @content
    end
  end

  def self.new(pull : JSON::PullParser) : Message
    role = Role::User
    content : String | Array(ContentBlock) = ""

    found_role = false
    found_content = false

    pull.read_object do |key|
      case key
      when "role"
        role = Role.parse(pull.read_string)
        found_role = true
      when "content"
        content = parse_content(pull)
        found_content = true
      else
        pull.skip
      end
    end

    raise JSON::ParseException.new("Missing required field 'role' in Message", 0, 0) unless found_role
    raise JSON::ParseException.new("Missing required field 'content' in Message", 0, 0) unless found_content

    new(role, content)
  end

  # Parses content field — either a string or an array of content blocks.
  protected def self.parse_content(pull : JSON::PullParser) : String | Array(ContentBlock)
    if pull.kind.string?
      pull.read_string
    else
      blocks = [] of ContentBlock
      pull.read_array { blocks << parse_content_block(pull) }
      blocks
    end
  end

  # Parses a single content block from a JSON object.
  protected def self.parse_content_block(pull : JSON::PullParser) : ContentBlock
    # Peek at the type first via JSON::Any to decide parsing strategy
    block_json = JSON::Any.new(pull)
    block_type = block_json["type"]?.try(&.as_s) || ""

    # For known types, re-parse with field extraction
    case block_type
    when "text", "image", "tool_use", "tool_result", "thinking"
      parse_known_content_block(block_type, block_json)
    else
      Content::Block.new(Content::UnknownData.new(block_type, block_json))
    end
  end

  # Parses a known content block type from its JSON representation.
  protected def self.parse_known_content_block(type : String, json : JSON::Any) : ContentBlock
    case type
    when "text"
      Content::Block.new(Content::TextData.new(json["text"].as_s))
    when "image"
      source = json["source"]
      Content::Block.new(Content::ImageData.new(source["media_type"].as_s, source["data"].as_s))
    when "tool_use"
      Content::Block.new(Content::ToolUseData.new(json["id"].as_s, json["name"].as_s, json["input"]))
    when "tool_result"
      content = json["content"]?
      parsed_content : String | Array(JSON::Any) = case content
      when .nil?  then ""
      when .as_s? then content.as_s
      else
        content.as_a
      end
      Content::Block.new(Content::ToolResultData.new(json["tool_use_id"].as_s, parsed_content, json["is_error"]?.try(&.as_bool) || false))
    when "thinking"
      Content::Block.new(Content::ThinkingData.new(json["thinking"].as_s, json["signature"]?.try(&.as_s)))
    else
      Content::Block.new(Content::UnknownData.new(type, json))
    end
  end
end
