require "json"
require "uri"

class Anthropic::Messages::BatchAPI
  ENDPOINT = "/v1/messages/batches"

  def initialize(@client : Client)
  end

  # Create a new message batch for asynchronous processing.
  def create(request : CreateMessageBatchRequest, request_options : RequestOptions? = nil) : MessageBatch
    response = @client.post(ENDPOINT, request.to_json, options: request_options)
    MessageBatch.from_json(response.body)
  end

  # Create a batch from an array of batch requests.
  def create(requests : Array(CreateMessageBatchRequest::BatchRequest), request_options : RequestOptions? = nil) : MessageBatch
    create(CreateMessageBatchRequest.new(requests), request_options)
  end

  # List all message batches with pagination.
  def list(params : ListParams = ListParams.new, request_options : RequestOptions? = nil) : Page(MessageBatch)
    response = @client.get("#{ENDPOINT}#{params.to_query_string}", options: request_options)
    Page(MessageBatch).from_json(response.body)
  end

  # Auto-paginating iterator for listing all message batches.
  # Returns an AutoPaginator that fetches pages lazily as you iterate.
  #
  # Example:
  # ```
  # client.batches.list_all(limit: 20).each do |batch|
  #   puts batch.id
  # end
  # ```
  def list_all(limit : Int32? = nil, request_options : RequestOptions? = nil) : AutoPaginator(MessageBatch)
    AutoPaginator(MessageBatch).new(limit: limit) do |params|
      list(params, request_options)
    end
  end

  # Retrieve a specific batch by ID.
  def retrieve(batch_id : String, request_options : RequestOptions? = nil) : MessageBatch
    response = @client.get("#{ENDPOINT}/#{URI.encode_path_segment(batch_id)}", options: request_options)
    MessageBatch.from_json(response.body)
  end

  # Cancel a batch that is in progress.
  def cancel(batch_id : String, request_options : RequestOptions? = nil) : MessageBatch
    response = @client.post("#{ENDPOINT}/#{URI.encode_path_segment(batch_id)}/cancel", "{}", options: request_options)
    MessageBatch.from_json(response.body)
  end

  # Get results for a completed batch.
  # Streams NDJSON results line-by-line for memory efficiency.
  #
  # The actual API returns a streaming NDJSON response at
  # `GET /v1/messages/batches/{batch_id}/results`.
  # This method first retrieves the batch to find the `results_url`,
  # then streams the NDJSON response and parses it line-by-line.
  #
  # Results are yielded one at a time, allowing processing of very large
  # batches without loading the entire response into memory.
  #
  # Raises:
  # - `BatchResultsNotReadyError` if the batch has not completed (results_url is nil)
  # - `URLAuthorityMismatchError` if the results_url authority differs from the client's base_url
  def results(batch_id : String, request_options : RequestOptions? = nil, &block : MessageBatchResult ->) : Nil
    # Get the batch to find the results_url
    batch = retrieve(batch_id, request_options)

    if results_url = batch.results_url
      # Validate and normalize the URL
      path = normalize_results_url(results_url)

      # Stream the results file, processing line by line
      @client.get_stream(path, options: request_options) do |response|
        response.body_io.each_line do |line|
          next if line.strip.empty?
          result = MessageBatchResult.from_json(line)
          block.call(result)
        end
      end
    else
      raise BatchResultsNotReadyError.new(batch_id, batch.processing_status)
    end
  end

  # Normalizes a results_url to a path suitable for the HTTP client.
  # Handles both absolute URLs (https://api.anthropic.com/v1/...) and
  # relative URLs (/v1/messages/batches/.../results).
  #
  # Security: Raises URLAuthorityMismatchError if the absolute URL authority
  # (scheme + host + port) differs from the configured client base_url.
  # This prevents unauthorized data access through manipulated URLs,
  # including scheme downgrades (http vs https) and port mismatches.
  private def normalize_results_url(url : String) : String
    uri = URI.parse(url)

    # If the URL has a scheme, it's absolute - validate authority and extract path
    if uri.scheme
      # Security check: ensure full authority matches configured base_url
      actual_authority = authority_for(uri)
      expected_authority = authority_for(URI.parse(@client.base_url))
      if actual_authority != expected_authority
        raise URLAuthorityMismatchError.new(expected_authority, actual_authority)
      end

      path = uri.path || "/"
      if query = uri.query
        "#{path}?#{query}"
      else
        path
      end
    else
      # Relative URL validation
      # Reject protocol-relative URLs (//host/path)
      if uri.host
        raise MalformedResultsURLError.new(url, "protocol-relative URLs are not allowed; use an absolute URL or a path")
      end

      # Reject empty or blank URLs
      if url.strip.empty?
        raise MalformedResultsURLError.new(url, "results URL must not be empty")
      end

      # Must start with / (absolute path)
      unless url.starts_with?("/")
        raise MalformedResultsURLError.new(url, "relative results URL must be an absolute path starting with /")
      end

      url
    end
  end

  # Builds the authority string (scheme://host[:port]) for a URI.
  # Only includes the port if it's non-default for the scheme
  # (non-80 for http, non-443 for https).
  private def authority_for(uri : URI) : String
    scheme = uri.scheme || "https"
    host = uri.host || ""
    port = uri.port
    port_suffix = if port.nil?
                    ""
                  elsif port == 443 && scheme == "https"
                    ""
                  elsif port == 80 && scheme == "http"
                    ""
                  else
                    ":#{port}"
                  end
    "#{scheme}://#{host}#{port_suffix}"
  end

  # Delete a message batch.
  # Sends `DELETE /v1/messages/batches/{batch_id}` and returns a
  # typed `MessageBatchDeleted` response.
  def delete(batch_id : String, request_options : RequestOptions? = nil) : MessageBatchDeleted
    response = @client.delete("#{ENDPOINT}/#{URI.encode_path_segment(batch_id)}", options: request_options)
    MessageBatchDeleted.from_json(response.body)
  end
end
