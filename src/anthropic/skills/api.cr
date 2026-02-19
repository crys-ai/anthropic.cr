require "json"
require "uri"

# Skills API client for managing Anthropic Skills.
#
# Skills require the beta header `skills-2025-10-02`.
# All methods automatically inject the required beta header.
#
# ## Usage
#
# ```
# client = Anthropic::Client.new
# skills = client.skills.list
# skills.data.each { |s| puts s.display_title }
# ```
class Anthropic::Skills::API
  ENDPOINT    = "/v1/skills"
  BETA_HEADER = "skills-2025-10-02"

  def initialize(@client : Client, *, @namespace_beta_headers : Array(String) = [] of String)
  end

  # Create a new skill by uploading content as multipart form data.
  #
  # This is the primary creation method. It uploads a zip archive containing
  # the skill definition (including `SKILL.md` and any supporting files) as a
  # multipart form-data POST.
  #
  # Parameters:
  # - request: An UploadSkillRequest containing the file content
  # - request_options: Optional per-request options
  #
  # Example:
  # ```
  # req = Anthropic::UploadSkillRequest.from_file("my_skill.zip")
  # skill = client.skills.create(req)
  # ```
  def create(request : UploadSkillRequest, request_options : RequestOptions? = nil) : Skill
    boundary = "----AnthropicBoundary#{Random.rand(Int32::MAX)}"
    body = build_multipart_body(request, boundary)

    merged = beta_options(request_options)

    # extra_body cannot be used with multipart uploads - raise early with clear message.
    # extra_body merging requires a JSON body, and multipart form data is not JSON.
    if merged.extra_body.try { |extra| !extra.empty? }
      raise ArgumentError.new(
        "extra_body cannot be used with multipart skill uploads. " \
        "Remove extra_body from RequestOptions when uploading skills."
      )
    end

    upload_opts = RequestOptions.new(
      timeout: merged.timeout,
      retry_policy: merged.retry_policy,
      beta_headers: merged.beta_headers,
      extra_headers: merge_multipart_headers(merged.extra_headers, boundary),
      extra_query: merged.extra_query,
    )

    response = @client.post(ENDPOINT, body, options: upload_opts)
    Skill.from_json(response.body)
  end

  # Create a new skill without uploading content (sends an empty JSON body).
  #
  # This overload sends `{}` as a JSON POST body instead of multipart upload.
  # Use this when you want to register a skill placeholder and upload content
  # later via `create_version(skill_id, upload_request)`.
  #
  # NOTE: This is a convenience overload. Not all Skills API versions may
  # support creation without content. Consult the Anthropic API documentation
  # for your beta version.
  #
  # Example:
  # ```
  # skill = client.skills.create
  # req = Anthropic::UploadSkillRequest.from_file("my_skill.zip")
  # version = client.skills.create_version(skill.id, req)
  # ```
  def create(request_options : RequestOptions? = nil) : Skill
    response = @client.post(ENDPOINT, "{}", options: beta_options(request_options))
    Skill.from_json(response.body)
  end

  # List skills with optional filtering and pagination.
  def list(params : SkillsListParams = SkillsListParams.new, request_options : RequestOptions? = nil) : SkillsListResponse
    response = @client.get("#{ENDPOINT}#{params.to_query_string}", options: beta_options(request_options))
    SkillsListResponse.from_json(response.body)
  end

  # Retrieve a specific skill by ID.
  def retrieve(skill_id : String, request_options : RequestOptions? = nil) : Skill
    response = @client.get("#{ENDPOINT}/#{URI.encode_path_segment(skill_id)}", options: beta_options(request_options))
    Skill.from_json(response.body)
  end

  # Delete a skill.
  def delete(skill_id : String, request_options : RequestOptions? = nil) : SkillDeleted
    response = @client.delete("#{ENDPOINT}/#{URI.encode_path_segment(skill_id)}", options: beta_options(request_options))
    SkillDeleted.from_json(response.body)
  end

  # Create a new version of a skill by uploading content as multipart form data.
  #
  # This is the primary version creation method. It uploads a zip archive
  # containing the updated skill definition as multipart form-data.
  #
  # Parameters:
  # - skill_id: The ID of the skill to create a version for
  # - request: An UploadSkillRequest containing the file content
  # - request_options: Optional per-request options
  #
  # Example:
  # ```
  # req = Anthropic::UploadSkillRequest.from_file("my_skill_v2.zip")
  # version = client.skills.create_version("skill_01ABC123", req)
  # ```
  def create_version(skill_id : String, request : UploadSkillRequest, request_options : RequestOptions? = nil) : SkillVersion
    boundary = "----AnthropicBoundary#{Random.rand(Int32::MAX)}"
    body = build_multipart_body(request, boundary)

    merged = beta_options(request_options)

    # extra_body cannot be used with multipart uploads - raise early with clear message.
    # extra_body merging requires a JSON body, and multipart form data is not JSON.
    if merged.extra_body.try { |extra| !extra.empty? }
      raise ArgumentError.new(
        "extra_body cannot be used with multipart skill uploads. " \
        "Remove extra_body from RequestOptions when uploading skills."
      )
    end

    upload_opts = RequestOptions.new(
      timeout: merged.timeout,
      retry_policy: merged.retry_policy,
      beta_headers: merged.beta_headers,
      extra_headers: merge_multipart_headers(merged.extra_headers, boundary),
      extra_query: merged.extra_query,
    )

    response = @client.post("#{ENDPOINT}/#{URI.encode_path_segment(skill_id)}/versions", body, options: upload_opts)
    SkillVersion.from_json(response.body)
  end

  # Create a new version of a skill without uploading content (sends an empty JSON body).
  #
  # This overload sends `{}` as a JSON POST body instead of multipart upload.
  # Use this when the API supports version creation without content, e.g. to
  # trigger a rebuild from existing server-side content.
  #
  # NOTE: This is a convenience overload. Not all Skills API versions may
  # support version creation without content. Consult the Anthropic API
  # documentation for your beta version.
  #
  # Example:
  # ```
  # version = client.skills.create_version("skill_01ABC123")
  # ```
  def create_version(skill_id : String, request_options : RequestOptions? = nil) : SkillVersion
    response = @client.post("#{ENDPOINT}/#{URI.encode_path_segment(skill_id)}/versions", "{}", options: beta_options(request_options))
    SkillVersion.from_json(response.body)
  end

  # List versions of a skill.
  def list_versions(skill_id : String, params : SkillVersionsListParams = SkillVersionsListParams.new, request_options : RequestOptions? = nil) : SkillVersionsListResponse
    response = @client.get("#{ENDPOINT}/#{URI.encode_path_segment(skill_id)}/versions#{params.to_query_string}", options: beta_options(request_options))
    SkillVersionsListResponse.from_json(response.body)
  end

  # Retrieve a specific version of a skill.
  def retrieve_version(skill_id : String, version : String, request_options : RequestOptions? = nil) : SkillVersion
    response = @client.get("#{ENDPOINT}/#{URI.encode_path_segment(skill_id)}/versions/#{URI.encode_path_segment(version)}", options: beta_options(request_options))
    SkillVersion.from_json(response.body)
  end

  # Delete a specific version of a skill.
  def delete_version(skill_id : String, version : String, request_options : RequestOptions? = nil) : SkillVersionDeleted
    response = @client.delete("#{ENDPOINT}/#{URI.encode_path_segment(skill_id)}/versions/#{URI.encode_path_segment(version)}", options: beta_options(request_options))
    SkillVersionDeleted.from_json(response.body)
  end

  # Merge beta header into request options, including namespace beta headers.
  private def beta_options(options : RequestOptions?) : RequestOptions
    existing_betas = options.try(&.beta_headers) || [] of String
    merged_betas = existing_betas.dup
    merged_betas.concat(@namespace_beta_headers)
    merged_betas << BETA_HEADER unless merged_betas.includes?(BETA_HEADER)
    merged_betas = merged_betas.uniq

    RequestOptions.new(
      timeout: options.try(&.timeout),
      retry_policy: options.try(&.retry_policy),
      beta_headers: merged_betas,
      extra_headers: options.try(&.extra_headers),
      extra_body: options.try(&.extra_body),
      extra_query: options.try(&.extra_query),
    )
  end

  # Build multipart form body for skill upload requests.
  private def build_multipart_body(request : UploadSkillRequest, boundary : String) : String
    String.build do |io|
      # file field
      io << "--#{boundary}\r\n"
      io << "Content-Disposition: form-data; name=\"file\"; filename=\"#{sanitize_filename(request.filename)}\"\r\n"
      io << "Content-Type: application/zip\r\n"
      io << "\r\n"
      io.write(request.content)
      io << "\r\n"

      io << "--#{boundary}--\r\n"
    end
  end

  # Merge multipart Content-Type header into existing extra headers.
  private def merge_multipart_headers(existing : HTTP::Headers?, boundary : String) : HTTP::Headers
    headers = existing ? existing.dup : HTTP::Headers.new
    headers["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
    headers
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
end
