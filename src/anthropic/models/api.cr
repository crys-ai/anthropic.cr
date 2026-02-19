require "uri"

class Anthropic::Models::API
  ENDPOINT = "/v1/models"

  def initialize(@client : Client)
  end

  # List all available models with pagination support.
  def list(params : ListParams = ListParams.new, request_options : RequestOptions? = nil) : Page(ModelInfo)
    response = @client.get("#{ENDPOINT}#{params.to_query_string}", options: request_options)
    Page(ModelInfo).from_json(response.body)
  end

  # Retrieve a specific model by ID.
  def retrieve(model_id : String, request_options : RequestOptions? = nil) : ModelInfo
    response = @client.get("#{ENDPOINT}/#{URI.encode_path_segment(model_id)}", options: request_options)
    ModelInfo.from_json(response.body)
  end

  # Auto-paginating iterator for listing all models.
  # Returns an AutoPaginator that fetches pages lazily as you iterate.
  #
  # Example:
  # ```
  # client.models.list_all(limit: 20).each do |model|
  #   puts model.id
  # end
  # ```
  def list_all(limit : Int32? = nil, request_options : RequestOptions? = nil) : AutoPaginator(ModelInfo)
    AutoPaginator(ModelInfo).new(limit: limit) do |params|
      list(params, request_options)
    end
  end
end
