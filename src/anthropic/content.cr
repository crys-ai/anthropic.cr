# Content module for typed message content blocks.
#
# Uses generics to provide compile-time type safety while
# maintaining a uniform interface for all content types.
#
# ## Usage
#
# ```
# text = Anthropic::Content.text("Hello!")
# text.data.text # => "Hello!"
#
# image = Anthropic::Content.image("image/png", base64_data)
# image.data.media_type # => "image/png"
# ```
module Anthropic::Content
  # Creates a text content block.
  def self.text(value : String) : Block(TextData)
    Block.new(TextData.new(value))
  end

  # Creates an image content block from base64 data.
  def self.image(media_type : String, data : String) : Block(ImageData)
    Block.new(ImageData.new(media_type, data))
  end

  # Creates an image content block from an ImageSource.
  def self.image(source : ImageSource) : Block(ImageData)
    Block.new(ImageData.new(source))
  end

  # Creates a tool use content block.
  def self.tool_use(id : String, name : String, input : JSON::Any) : Block(ToolUseData)
    Block.new(ToolUseData.new(id, name, input))
  end

  # Creates a tool result content block with string content.
  def self.tool_result(tool_use_id : String, content : String, is_error : Bool = false) : Block(ToolResultData)
    Block.new(ToolResultData.new(tool_use_id, content, is_error))
  end

  # Creates a tool result content block with array content.
  def self.tool_result(tool_use_id : String, content : Array(JSON::Any), is_error : Bool = false) : Block(ToolResultData)
    Block.new(ToolResultData.new(tool_use_id, content, is_error))
  end
end

# Union type for content blocks in messages.
alias Anthropic::ContentBlock = Anthropic::Content::Block(Anthropic::Content::TextData) |
                                Anthropic::Content::Block(Anthropic::Content::ImageData) |
                                Anthropic::Content::Block(Anthropic::Content::ToolUseData) |
                                Anthropic::Content::Block(Anthropic::Content::ToolResultData) |
                                Anthropic::Content::Block(Anthropic::Content::UnknownData)
