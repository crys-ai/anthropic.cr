# Beta namespace wrapper for Messages Batches API.
#
# Provides access to the Messages Batches API through the beta namespace,
# automatically merging beta headers into all requests.
#
# ## Usage
#
# ```
# client = Anthropic::Client.new
#
# # Access batches through beta namespace
# batch = client.beta.messages.batches.create(request)
#
# # With custom beta headers
# batch = client.beta(["custom-feature"]).messages.batches.create(request)
# ```
class Anthropic::Beta::BatchesAPI
  def initialize(@client : Client, @namespace_beta_headers : Array(String))
  end

  # Create a new message batch for asynchronous processing.
  def create(request : CreateMessageBatchRequest, request_options : RequestOptions? = nil) : MessageBatch
    @client.batches.create(request, merge_options(request_options))
  end

  # Create a batch from an array of batch requests.
  def create(requests : Array(CreateMessageBatchRequest::BatchRequest), request_options : RequestOptions? = nil) : MessageBatch
    @client.batches.create(requests, merge_options(request_options))
  end

  # List all message batches with pagination.
  def list(params : ListParams = ListParams.new, request_options : RequestOptions? = nil) : Page(MessageBatch)
    @client.batches.list(params, merge_options(request_options))
  end

  # Auto-paginating iterator for listing all message batches.
  def list_all(limit : Int32? = nil, request_options : RequestOptions? = nil) : AutoPaginator(MessageBatch)
    @client.batches.list_all(limit, merge_options(request_options))
  end

  # Retrieve a specific batch by ID.
  def retrieve(batch_id : String, request_options : RequestOptions? = nil) : MessageBatch
    @client.batches.retrieve(batch_id, merge_options(request_options))
  end

  # Cancel a batch that is in progress.
  def cancel(batch_id : String, request_options : RequestOptions? = nil) : MessageBatch
    @client.batches.cancel(batch_id, merge_options(request_options))
  end

  # Delete a message batch.
  def delete(batch_id : String, request_options : RequestOptions? = nil) : MessageBatchDeleted
    @client.batches.delete(batch_id, merge_options(request_options))
  end

  # Get results for a completed batch.
  def results(batch_id : String, request_options : RequestOptions? = nil, &block : MessageBatchResult ->) : Nil
    @client.batches.results(batch_id, merge_options(request_options), &block)
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
