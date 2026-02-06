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

    pull.read_object do |key|
      case key
      when "role"
        role = Role.parse(pull.read_string)
      when "content"
        content = parse_content(pull)
      else
        pull.skip
      end
    end

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
    block_type = ""
    block_text = ""
    source_media_type = ""
    source_data = ""
    block_id = ""
    block_name = ""
    block_input = JSON::Any.new(nil)
    tool_use_id = ""
    is_error = false

    pull.read_object do |block_key|
      case block_key
      when "type" then block_type = pull.read_string
      when "text" then block_text = pull.read_string
      when "source"
        parse_source(pull) do |media_type, data|
          source_media_type = media_type
          source_data = data
        end
      when "id"          then block_id = pull.read_string
      when "name"        then block_name = pull.read_string
      when "input"       then block_input = JSON::Any.new(pull)
      when "tool_use_id" then tool_use_id = pull.read_string
      when "content"     then block_text = parse_tool_result_content(pull)
      when "is_error"    then is_error = pull.read_bool
      else                    pull.skip
      end
    end

    build_content_block(block_type, block_text, source_media_type, source_data, block_id, block_name, block_input, tool_use_id, is_error)
  end

  # Parses the "source" sub-object inside an image content block.
  protected def self.parse_source(pull : JSON::PullParser, &) : Nil
    media_type = ""
    data = ""
    pull.read_object do |source_key|
      case source_key
      when "media_type" then media_type = pull.read_string
      when "data"       then data = pull.read_string
      else                   pull.skip
      end
    end
    yield media_type, data
  end

  # Parses tool_result content — either a string or an array of content blocks.
  # When array, extracts text from text blocks and joins.
  protected def self.parse_tool_result_content(pull : JSON::PullParser) : String
    if pull.kind.string?
      pull.read_string
    else
      parts = [] of String
      pull.read_array do
        block = JSON::Any.new(pull)
        if block["type"]?.try(&.as_s) == "text"
          parts << block["text"].as_s
        end
      end
      parts.join
    end
  end

  # Builds the appropriate ContentBlock from parsed fields.
  protected def self.build_content_block(
    type : String, text : String,
    source_media_type : String, source_data : String,
    id : String, name : String, input : JSON::Any,
    tool_use_id : String, is_error : Bool,
  ) : ContentBlock
    case type
    when "text"        then Content::Block.new(Content::TextData.new(text))
    when "image"       then Content::Block.new(Content::ImageData.new(source_media_type, source_data))
    when "tool_use"    then Content::Block.new(Content::ToolUseData.new(id, name, input))
    when "tool_result" then Content::Block.new(Content::ToolResultData.new(tool_use_id, text, is_error))
    else                    raise ArgumentError.new("Unknown content block type: #{type}")
    end
  end
end
