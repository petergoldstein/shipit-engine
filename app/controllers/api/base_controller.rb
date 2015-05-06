module Api
  class BaseController < ActionController::Base
    include Shipster::Engine.routes.url_helpers
    include Rendering
    include Cacheable
    include Paginable

    rescue_from ApiClient::InsufficientPermission, with: :insufficient_permission

    class << self
      def require_permission(operation, scope, options = {})
        before_action(options) { require_permission!(operation, scope) }
      end
    end

    before_action :authenticate_api_client

    def index
      render json: {stacks_url: api_stacks_url}
    end

    private

    def authenticate_api_client
      @current_api_client = authenticate_with_http_basic do |*parts|
        token = parts.select(&:present?).join('--')
        ApiClient.authenticate(token)
      end
      return if @current_api_client
      headers['WWW-Authenticate'] = 'Basic realm="Authentication token"'
      render status: :unauthorized, json: {message: 'Bad credentials'}
    end

    attr_reader :current_api_client

    def current_user
      @current_user ||= identify_user || AnonymousUser.new
    end

    def identify_user
      user_login = request.headers['X-Shipster-User'].presence
      User.find_by(login: user_login) if user_login
    end

    def stacks
      @stacks ||= current_api_client.stack_id? ? Stack.where(id: current_api_client.stack_id) : Stack.all
    end

    def stack
      @stack ||= stacks.from_param!(params[:stack_id])
    end

    def require_permission!(operation, scope)
      current_api_client.check_permissions!(operation, scope)
    end

    def insufficient_permission(error)
      render status: :forbidden, json: {message: error.message}
    end
  end
end
