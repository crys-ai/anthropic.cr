require "json"

# Structured output helper for extracting typed JSON from tool-use responses.
#
# Uses the tool-use pattern to get structured data from Claude:
# define a tool with a JSON schema, force the model to use it,
# then extract and parse the tool's input as your structured data.
#
# ## Usage
#
# ```
# schema = JSON.parse(%({"type": "object", "properties": {"name": {"type": "string"}}, "required": ["name"]}))
# tool = Anthropic::StructuredOutput.tool("extract_data", schema, description: "Extract structured data")
# choice = Anthropic::StructuredOutput.tool_choice("extract_data")
#
# response = client.messages.create(
#   model: Anthropic::Model.sonnet,
#   messages: [Anthropic::Message.user("My name is Alice")],
#   max_tokens: 1024,
#   tools: [tool],
#   tool_choice: choice,
# )
#
# result = Anthropic::StructuredOutput.extract(response)
# result["name"].as_s # => "Alice"
# ```
module Anthropic::StructuredOutput
  # Default tool name used for structured output extraction.
  DEFAULT_TOOL_NAME = "structured_output"

  # Creates a tool definition for structured output extraction.
  #
  # The tool's input_schema defines the shape of the structured data
  # the model should return.
  def self.tool(
    name : String = DEFAULT_TOOL_NAME,
    schema : JSON::Any = JSON::Any.new({} of String => JSON::Any),
    description : String? = nil,
  ) : ToolDefinition
    ToolDefinition.new(
      name: name,
      input_schema: schema,
      description: description,
    )
  end

  # Creates a tool choice that forces the model to use the structured output tool.
  def self.tool_choice(name : String = DEFAULT_TOOL_NAME) : ToolChoice
    ToolChoice.tool(name)
  end

  # Extracts the structured output from a response.
  #
  # Looks for a tool_use block matching the given tool name and returns
  # its input as JSON::Any. Returns nil if no matching block is found.
  def self.extract(response : Messages::Response, tool_name : String = DEFAULT_TOOL_NAME) : JSON::Any?
    response.tool_use_blocks.find { |block| block.name == tool_name }.try(&.input)
  end

  # Extracts the structured output, raising if not found.
  #
  # Raises `ExtractionError` if no matching tool_use block is found.
  def self.extract!(response : Messages::Response, tool_name : String = DEFAULT_TOOL_NAME) : JSON::Any
    extract(response, tool_name) || raise ExtractionError.new(
      "No tool_use block found for '#{tool_name}' in response"
    )
  end

  # Extracts and deserializes structured output to a typed struct.
  #
  # Type T must include JSON::Serializable or have a .from_json method.
  # Returns nil if no matching tool_use block is found.
  def self.extract_as(type : T.class, response : Messages::Response, tool_name : String = DEFAULT_TOOL_NAME) : T? forall T
    json = extract(response, tool_name)
    return unless json

    T.from_json(json.to_json)
  end

  # Check if a response contains structured output from the named tool.
  def self.has_output?(response : Messages::Response, tool_name : String = DEFAULT_TOOL_NAME) : Bool
    response.tool_use_blocks.any? { |block| block.name == tool_name }
  end

  # Error raised when structured output extraction fails.
  class ExtractionError < Exception
  end
end
