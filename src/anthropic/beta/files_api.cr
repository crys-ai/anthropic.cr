# Beta-scoped file operations with automatic beta header merging.
#
# Wraps `Files::API` so that every request includes the beta namespace
# headers configured on the parent `Beta::API`, merged (deduplicated)
# with any per-request options the caller passes.
#
# ## Usage
#
# ```
# client = Anthropic::Client.new
#
# # Upload a file through the beta namespace
# file = client.beta(["files-beta-2025"]).files.upload("doc.txt", "content")
#
# # Per-request options are merged, not overwritten
# opts = Anthropic::RequestOptions.new(beta_headers: ["extra-beta"])
# file = client.beta(["files-beta-2025"]).files.retrieve("file_123", opts)
# # => request includes both "files-beta-2025" AND "extra-beta"
# ```
class Anthropic::Beta::FilesAPI
  def initialize(@client : Client, @namespace_beta_headers : Array(String))
  end

  # Upload a file via an UploadFileRequest.
  def upload(request : UploadFileRequest, request_options : RequestOptions? = nil) : File
    @client.files.upload(request, merge_options(request_options))
  end

  # Upload a file from a string.
  def upload(filename : String, content : String, mime_type : String? = nil, request_options : RequestOptions? = nil) : File
    @client.files.upload(filename, content, mime_type, merge_options(request_options))
  end

  # List files with pagination.
  def list(params : ListParams = ListParams.new, request_options : RequestOptions? = nil) : Page(File)
    @client.files.list(params, merge_options(request_options))
  end

  # Auto-paginating iterator for listing all files.
  def list_all(limit : Int32? = nil, request_options : RequestOptions? = nil) : AutoPaginator(File)
    @client.files.list_all(limit, merge_options(request_options))
  end

  # Retrieve a specific file by ID.
  def retrieve(file_id : String, request_options : RequestOptions? = nil) : File
    @client.files.retrieve(file_id, merge_options(request_options))
  end

  # Delete a file.
  def delete(file_id : String, request_options : RequestOptions? = nil) : FileDeleted
    @client.files.delete(file_id, merge_options(request_options))
  end

  # Download file content as raw bytes.
  def download(file_id : String, request_options : RequestOptions? = nil) : Bytes
    @client.files.download(file_id, merge_options(request_options))
  end

  # Download file content as string.
  def download_string(file_id : String, request_options : RequestOptions? = nil) : String
    @client.files.download_string(file_id, merge_options(request_options))
  end

  # Download file content as base64.
  def download_base64(file_id : String, request_options : RequestOptions? = nil) : String
    @client.files.download_base64(file_id, merge_options(request_options))
  end

  # Merge namespace beta headers with per-request options.
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
