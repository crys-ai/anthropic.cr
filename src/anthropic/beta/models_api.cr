# Beta-scoped Models API with automatic beta header merging.
#
# Provides access to the Models API through the beta namespace, automatically
# merging any beta namespace headers with per-request options.
#
# ## Usage
#
# ```
# client = Anthropic::Client.new
#
# # Access models through beta namespace
# models = client.beta.models.list
#
# # With custom beta headers
# models = client.beta(["custom-beta"]).models.list
# ```
class Anthropic::Beta::ModelsAPI
  def initialize(@client : Client, @namespace_beta_headers : Array(String))
  end

  # List all available models with pagination support.
  #
  # Beta namespace headers are automatically merged with any per-request options.
  def list(params : ListParams = ListParams.new, request_options : RequestOptions? = nil) : Page(ModelInfo)
    @client.models.list(params, merge_options(request_options))
  end

  # Retrieve a specific model by ID.
  #
  # Beta namespace headers are automatically merged with any per-request options.
  def retrieve(model_id : String, request_options : RequestOptions? = nil) : ModelInfo
    @client.models.retrieve(model_id, merge_options(request_options))
  end

  # Auto-paginating iterator for listing all models.
  #
  # Beta namespace headers are automatically merged with any per-request options.
  #
  # Example:
  # ```
  # client.beta.models.list_all(limit: 20).each do |model|
  #   puts model.id
  # end
  # ```
  def list_all(limit : Int32? = nil, request_options : RequestOptions? = nil) : AutoPaginator(ModelInfo)
    @client.models.list_all(limit, merge_options(request_options))
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
