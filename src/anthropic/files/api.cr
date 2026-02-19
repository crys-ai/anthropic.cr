require "json"
require "base64"
require "uri"

class Anthropic::Files::API
  ENDPOINT = "/v1/files"

  def initialize(@client : Client)
  end

  # Upload a file.
  def upload(request : UploadFileRequest, request_options : RequestOptions? = nil) : File
    # Build multipart form data
    boundary = "----AnthropicBoundary#{Random.rand(Int32::MAX)}"
    body = String.build do |io|
      # filename field
      io << "--#{boundary}\r\n"
      io << "Content-Disposition: form-data; name=\"filename\"\r\n\r\n"
      io << sanitize_filename(request.filename)
      io << "\r\n"

      # file data field
      io << "--#{boundary}\r\n"
      io << "Content-Disposition: form-data; name=\"file\"; filename=\"#{sanitize_filename(request.filename)}\"\r\n"
      if mime = request.mime_type
        sanitized = sanitize_header_value(mime)
        if valid_mime_type?(sanitized)
          io << "Content-Type: #{sanitized}\r\n"
        end
      end
      io << "\r\n"
      io.write(request.content)
      io << "\r\n"

      io << "--#{boundary}--\r\n"
    end

    # Build RequestOptions with multipart Content-Type header.
    # Merge caller-provided extra_headers first, then set Content-Type last
    # so the multipart boundary always wins (callers cannot clobber it).
    merged_headers = HTTP::Headers.new
    if extra = request_options.try(&.extra_headers)
      extra.each do |key, values|
        merged_headers[key] = values.join(",")
      end
    end
    merged_headers["Content-Type"] = "multipart/form-data; boundary=#{boundary}"

    # extra_body cannot be used with multipart uploads - raise early with clear message.
    # extra_body merging requires a JSON body, and multipart form data is not JSON.
    if request_options.try(&.extra_body).try { |body_fields| !body_fields.empty? }
      raise ArgumentError.new(
        "extra_body cannot be used with multipart file uploads. " \
        "Remove extra_body from RequestOptions when uploading files."
      )
    end

    opts = RequestOptions.new(
      timeout: request_options.try(&.timeout),
      retry_policy: request_options.try(&.retry_policy),
      beta_headers: request_options.try(&.beta_headers),
      extra_headers: merged_headers,
      extra_query: request_options.try(&.extra_query),
    )

    response = @client.post(ENDPOINT, body, options: opts)
    File.from_json(response.body)
  end

  # Upload a file from a string.
  def upload(filename : String, content : String, mime_type : String? = nil, request_options : RequestOptions? = nil) : File
    upload(UploadFileRequest.from_string(filename, content, mime_type), request_options)
  end

  # List all files with pagination.
  def list(params : ListParams = ListParams.new, request_options : RequestOptions? = nil) : Page(File)
    response = @client.get("#{ENDPOINT}#{params.to_query_string}", options: request_options)
    Page(File).from_json(response.body)
  end

  # Auto-paginating iterator for listing all files.
  # Returns an AutoPaginator that fetches pages lazily as you iterate.
  #
  # Example:
  # ```
  # client.files.list_all(limit: 20).each do |file|
  #   puts file.filename
  # end
  # ```
  def list_all(limit : Int32? = nil, request_options : RequestOptions? = nil) : AutoPaginator(File)
    AutoPaginator(File).new(limit: limit) do |params|
      list(params, request_options)
    end
  end

  # Retrieve a specific file by ID.
  def retrieve(file_id : String, request_options : RequestOptions? = nil) : File
    response = @client.get("#{ENDPOINT}/#{URI.encode_path_segment(file_id)}", options: request_options)
    File.from_json(response.body)
  end

  # Delete a file.
  def delete(file_id : String, request_options : RequestOptions? = nil) : FileDeleted
    response = @client.delete("#{ENDPOINT}/#{URI.encode_path_segment(file_id)}", options: request_options)
    FileDeleted.from_json(response.body)
  end

  # Download file content as raw bytes.
  def download(file_id : String, request_options : RequestOptions? = nil) : Bytes
    response = @client.get("#{ENDPOINT}/#{URI.encode_path_segment(file_id)}/content", options: request_options)
    response.body.to_slice.dup
  end

  # Download file content as string.
  def download_string(file_id : String, request_options : RequestOptions? = nil) : String
    response = @client.get("#{ENDPOINT}/#{URI.encode_path_segment(file_id)}/content", options: request_options)
    response.body
  end

  # Download file content as base64.
  def download_base64(file_id : String, request_options : RequestOptions? = nil) : String
    Base64.strict_encode(download(file_id, request_options))
  end

  # Sanitize a filename for use in Content-Disposition headers.
  # Strips CRLF and null bytes to prevent header injection, and escapes
  # backslashes and double quotes for correct field parsing.
  private def sanitize_filename(name : String) : String
    name.gsub('\0', "")
      .gsub('\r', "")
      .gsub('\n', "")
      .gsub('\\', "\\\\")
      .gsub('"', "\\\"")
  end

  # Sanitize a value for use in multipart headers.
  # Strips CRLF and null bytes to prevent header injection.
  private def sanitize_header_value(value : String) : String
    value.gsub('\0', "").gsub('\r', "").gsub('\n', "")
  end

  # Validates that a MIME type has a basic type/subtype structure.
  # Returns false for empty, whitespace-containing, control-character-containing,
  # or structurally malformed values.
  private def valid_mime_type?(value : String) : Bool
    stripped = value.strip
    return false if stripped.empty?
    parts = stripped.split('/')
    return false unless parts.size == 2
    return false if parts[0].empty? || parts[1].empty?
    # Reject any whitespace or control characters
    stripped.each_char do |char|
      return false if char.ascii_whitespace? || char.ord < 0x20 || char.ord == 0x7F
    end
    true
  end
end
