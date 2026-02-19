# Beta namespace wrapper for Messages API.
#
# Provides access to Messages API methods and sub-resources (e.g. batches)
# through the beta namespace, automatically merging beta headers into all
# requests.
#
# ## Usage
#
# ```
# client = Anthropic::Client.new
#
# # Access messages API with beta headers
# response = client.beta.messages.create(request)
#
# # Stream with beta headers
# client.beta.messages.stream(request) { |event| puts event }
#
# # Access batches through beta.messages namespace
# batch = client.beta.messages.batches.create(request)
#
# # With custom beta headers
# batch = client.beta(["custom-feature"]).messages.batches.list
# ```
class Anthropic::Beta::MessagesAPI
  def initialize(@client : Client, @namespace_beta_headers : Array(String))
  end

  # Create a message with beta headers automatically merged.
  #
  # Beta namespace headers are merged with any per-request options.
  # See `Messages::API#create` for full parameter documentation.
  def create(request : Messages::Request, request_options : RequestOptions? = nil) : Messages::Response
    @client.messages.create(request, merge_options(request_options))
  end

  # Create a message with beta headers automatically merged (convenience overload).
  #
  # Beta namespace headers are merged with any per-request options.
  # See `Messages::API#create` for full parameter documentation.
  def create(
    model : Model | String,
    messages : Array(Message),
    max_tokens : Int32,
    request_options : RequestOptions? = nil,
    **options,
  ) : Messages::Response
    @client.messages.create(model, messages, max_tokens, merge_options(request_options), **options)
  end

  # Stream a message with beta headers automatically merged.
  #
  # Beta namespace headers are merged with any per-request options.
  # See `Messages::API#stream` for full parameter documentation.
  def stream(request : Messages::Request, request_options : RequestOptions? = nil, &block : StreamEvent ->) : Nil
    @client.messages.stream(request, merge_options(request_options), &block)
  end

  # Stream a message with beta headers automatically merged (convenience overload).
  #
  # Beta namespace headers are merged with any per-request options.
  # See `Messages::API#stream` for full parameter documentation.
  def stream(
    model : Model | String,
    messages : Array(Message),
    max_tokens : Int32,
    request_options : RequestOptions? = nil,
    **options,
    &block : StreamEvent ->
  ) : Nil
    @client.messages.stream(model, messages, max_tokens, merge_options(request_options), **options, &block)
  end

  # Count tokens with beta headers automatically merged.
  #
  # Beta namespace headers are merged with any per-request options.
  # See `Messages::API#count_tokens` for full parameter documentation.
  def count_tokens(request : Messages::CountTokensRequest, request_options : RequestOptions? = nil) : Messages::CountTokensResponse
    @client.messages.count_tokens(request, merge_options(request_options))
  end

  # Count tokens with beta headers automatically merged (convenience overload).
  #
  # Beta namespace headers are merged with any per-request options.
  # See `Messages::API#count_tokens` for full parameter documentation.
  def count_tokens(
    model : Model | String,
    messages : Array(Message),
    system : String? = nil,
    request_options : RequestOptions? = nil,
  ) : Messages::CountTokensResponse
    @client.messages.count_tokens(model, messages, system, merge_options(request_options))
  end

  # Access the Batches API through the beta messages namespace.
  #
  # Returns a `Beta::BatchesAPI` that automatically merges beta headers
  # into all batch requests.
  #
  # Example:
  # ```
  # client.beta.messages.batches.create(request)
  # client.beta(["custom-beta"]).messages.batches.list
  # ```
  def batches : Beta::BatchesAPI
    @batches ||= Beta::BatchesAPI.new(@client, @namespace_beta_headers)
  end

  private def merge_options(options : RequestOptions?) : RequestOptions
    existing_betas = options.try(&.beta_headers) || [] of String
    merged = (@namespace_beta_headers + existing_betas).uniq

    RequestOptions.new(
      timeout: options.try(&.timeout),
      retry_policy: options.try(&.retry_policy),
      beta_headers: merged,
      extra_headers: options.try(&.extra_headers),
      extra_body: options.try(&.extra_body),
      extra_query: options.try(&.extra_query),
    )
  end
end
