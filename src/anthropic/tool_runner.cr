require "json"

# Bounded tool-runner loop for agentic workflows.
#
# Manages the tool_use -> tool_result conversation loop with configurable bounds.
# The runner automatically handles the cycle of:
# 1. Sending a request to the API
# 2. Checking if the response contains tool_use blocks
# 3. Executing each tool via the provided block
# 4. Appending assistant response + tool results to the conversation
# 5. Repeating until no tool_use or max_iterations is reached
#
# ## Usage
#
# ```
# client = Anthropic::Client.new
#
# request = Anthropic::Messages::Request.new(
#   model: Anthropic::Model.sonnet,
#   messages: [Anthropic::Message.user("What's the weather in SF?")],
#   max_tokens: 1024,
#   tools: [weather_tool]
# )
#
# result = Anthropic::ToolRunner.run(client, request) do |tool_block|
#   # Execute the tool and return JSON result
#   if tool_block.name == "get_weather"
#     JSON.parse(%({"temperature": 72, "condition": "sunny"}))
#   else
#     JSON.parse(%({"error": "Unknown tool"}))
#   end
# end
#
# puts result.text # Final response after tool execution
# ```
#
# ## Bounds
#
# - `max_iterations`: Maximum number of tool rounds (default: 10)
# - Returns early if stop_reason != "tool_use"
module Anthropic::ToolRunner
  # Run a bounded tool loop.
  #
  # Parameters:
  # - client: The Anthropic client to use
  # - initial_request: The initial messages request
  # - max_iterations: Maximum tool execution rounds (default: 10)
  # - request_options: Per-request options forwarded to each API call
  # - block: Executor that receives each tool_use block and returns a JSON result
  #
  # Returns:
  # - The final Messages::Response (when stop_reason != "tool_use" or max_iterations reached)
  #
  # Yields:
  # - ResponseToolUseBlock for each tool that needs execution
  #
  # Example:
  # ```
  # result = ToolRunner.run(client, request, max_iterations: 5) do |tool|
  #   execute_tool(tool.name, tool.input)
  # end
  # ```
  def self.run(
    client : Client,
    initial_request : Messages::Request,
    max_iterations : Int32 = 10,
    request_options : RequestOptions? = nil,
    & : ResponseToolUseBlock -> (String | JSON::Any)
  ) : Messages::Response
    raise ArgumentError.new(
      "max_iterations must be non-negative, got #{max_iterations}"
    ) if max_iterations < 0

    request = initial_request
    messages = request.messages.dup
    iteration = 0

    loop do
      response = client.messages.create(request, request_options)

      # If no tool use requested or max iterations reached, return
      if response.stop_reason != Messages::Response::StopReason::ToolUse || iteration >= max_iterations
        return response
      end

      # Guard: stop_reason=tool_use but no tool_use blocks is an unexpected state
      if response.tool_use_blocks.empty?
        raise ToolUseError.new(
          "Response has stop_reason=tool_use but contains no tool_use content blocks. " \
          "This indicates an unexpected API response."
        )
      end

      # Collect tool results by executing each tool_use block
      tool_result_blocks = [] of ContentBlock
      response.tool_use_blocks.each do |tool_block|
        result = yield tool_block
        content_str = result.is_a?(JSON::Any) ? result.to_json : result
        tool_result_blocks << Content.tool_result(tool_block.id, content_str)
      end

      # Append assistant response + tool results to messages
      messages << build_assistant_message(response)
      messages << Message.new(role: Message::Role::User, content: tool_result_blocks)

      # Build new request with updated messages
      request = Messages::Request.new(
        model: request.model,
        messages: messages,
        max_tokens: request.max_tokens,
        system: request.system,
        temperature: request.temperature,
        top_p: request.top_p,
        top_k: request.top_k,
        stop_sequences: request.stop_sequences,
        metadata: request.metadata,
        tools: request.tools,
        tool_choice: request.tool_choice,
        thinking: request.thinking,
      )

      iteration += 1
    end
  end

  # Build an assistant message from a response.
  # Converts response content blocks to request content blocks.
  private def self.build_assistant_message(response : Messages::Response) : Message
    blocks = [] of ContentBlock
    response.content.each do |block|
      case block
      when ResponseTextBlock
        blocks << Content.text(block.text)
      when ResponseToolUseBlock
        blocks << Content.tool_use(block.id, block.name, block.input)
      when ResponseThinkingBlock
        blocks << Content.thinking(block.thinking, block.signature)
      when ResponseUnknownBlock
        blocks << Content::Block.new(Content::UnknownData.new(block.type, block.raw))
      end
    end
    Message.new(role: Message::Role::Assistant, content: blocks)
  end
end
