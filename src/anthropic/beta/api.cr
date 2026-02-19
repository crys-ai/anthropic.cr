require "json"

# Beta namespace for opt-in access to beta-only API features.
#
# The beta namespace provides a clean interface for accessing features that
# require beta headers, automatically injecting the appropriate headers.
#
# ## Usage
#
# ```
# client = Anthropic::Client.new
#
# # Access skills through beta namespace
# skills = client.beta.skills.list
#
# # Access messages with beta headers automatically merged
# response = client.beta.messages.create(request)
#
# # Use with additional beta headers
# options = client.beta.options(["future-feature-2025-01-01"])
# client.messages.create(request, request_options: options)
# ```
class Anthropic::Beta::API
  getter client : Client
  @beta_headers : Array(String)

  # Create a beta API wrapper.
  #
  # Parameters:
  # - client: The Anthropic client to wrap
  # - beta_headers: Default beta headers to include in all requests
  def initialize(@client : Client, beta_headers : Array(String) = [] of String)
    # Defensive copy to prevent external mutation
    @beta_headers = beta_headers.dup
  end

  # Returns a copy of the beta headers to prevent external mutation.
  def beta_headers : Array(String)
    @beta_headers.dup
  end

  # Access the Skills API through the beta namespace.
  #
  # Skills require the `skills-2025-10-02` beta header.
  # This accessor provides a clean way to access skills with beta opt-in.
  # The beta namespace headers are automatically merged with the skills
  # beta header in all requests.
  #
  # Example:
  # ```
  # skills = client.beta.skills.list
  # skills = client.beta(["custom-beta"]).skills.list # includes both headers
  # ```
  def skills : Skills::API
    @skills ||= Skills::API.new(@client, namespace_beta_headers: @beta_headers)
  end

  # Access the Messages API through the beta namespace.
  #
  # This provides a messages interface that automatically merges the
  # beta namespace's headers into all requests. Use this when you need
  # beta features in the Messages API without manually managing headers.
  #
  # Example:
  # ```
  # response = client.beta(["some-beta"]).messages.create(request)
  # ```
  def messages : Beta::MessagesAPI
    @messages ||= Beta::MessagesAPI.new(@client, @beta_headers)
  end

  # Access the Models API through the beta namespace.
  #
  # Beta namespace headers are automatically merged into all requests.
  # This provides a clean way to access models with beta opt-in.
  #
  # Example:
  # ```
  # models = client.beta.models.list
  # models = client.beta(["custom-beta"]).models.retrieve("claude-3-5-sonnet-20241022")
  # ```
  def models : Beta::ModelsAPI
    @models ||= Beta::ModelsAPI.new(@client, @beta_headers)
  end

  # Access the Files API through the beta namespace.
  #
  # File operations performed through this accessor automatically include
  # the beta namespace headers in every request. This is useful for
  # accessing file features that require beta opt-in.
  #
  # Example:
  # ```
  # file = client.beta(["files-beta-2025"]).files.upload("doc.txt", "content")
  # file = client.beta(["files-beta-2025"]).files.retrieve("file_123")
  # ```
  def files : Beta::FilesAPI
    @files ||= Beta::FilesAPI.new(@client, @beta_headers)
  end

  # Build request options with beta headers merged.
  #
  # Creates RequestOptions that include both the beta namespace's default
  # headers and any additional beta headers passed to this method.
  #
  # Parameters:
  # - additional_betas: Extra beta headers to include for this request
  #
  # Returns:
  # - RequestOptions with merged beta headers
  #
  # Example:
  # ```
  # options = client.beta.options(["experimental-feature"])
  # client.messages.create(request, request_options: options)
  # ```
  def options(additional_betas : Array(String) = [] of String) : RequestOptions
    merged = (@beta_headers + additional_betas).uniq
    RequestOptions.new(beta_headers: merged)
  end

  # Merge beta headers into existing request options.
  #
  # Takes an existing RequestOptions and returns a new one with
  # beta headers merged in. Useful for adding beta headers to
  # requests that already have other options set.
  #
  # Parameters:
  # - options: Existing request options to merge with
  #
  # Returns:
  # - New RequestOptions with beta headers merged
  #
  # Example:
  # ```
  # base_options = Anthropic::RequestOptions.new(timeout: 30.seconds)
  # options = client.beta.merge_options(base_options)
  # ```
  def merge_options(options : RequestOptions?) : RequestOptions
    existing_betas = options.try(&.beta_headers) || [] of String
    merged = (@beta_headers + existing_betas).uniq

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
