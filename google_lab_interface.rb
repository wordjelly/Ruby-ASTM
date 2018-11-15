require 'google/apis/script_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
require '/home/bhargav/Github/ruby_astm/adapter'

class Google_Lab_Interface < Adapter

  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'.freeze
  APPLICATION_NAME = 'Google Apps Script API Ruby Quickstart'.freeze
  CREDENTIALS_PATH = 'credentials.json'.freeze
  # The file token.yaml stores the user's access and refresh tokens, and is
  # created automatically when the authorization flow completes for the first
  # time.
  TOKEN_PATH = 'token.yaml'.freeze
  SCOPE = 'https://www.googleapis.com/auth/script.projects'.freeze

  SCOPES = ["https://www.googleapis.com/auth/documents","https://www.googleapis.com/auth/drive","https://www.googleapis.com/auth/script.projects","https://www.googleapis.com/auth/spreadsheets"]

  $service = nil
  SCRIPT_ID = "M7JDg7zmo0Xldo4RTWFGCsI2yotVzKYhk"

  ##
  # Ensure valid credentials, either by restoring from the saved credentials
  # files or intitiating an OAuth2 authorization. If authorization is required,
  # the user's default browser will be launched to approve the request.
  #
  # @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
  def authorize
    client_id = Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPES, token_store)
    user_id = 'default'
    credentials = authorizer.get_credentials(user_id)
    if credentials.nil?
      url = authorizer.get_authorization_url(base_url: OOB_URI)
      puts 'Open the following URL in the browser and enter the ' \
           "resulting code after authorization:\n" + url
      code = gets
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, code: code, base_url: OOB_URI
      )
    end
    credentials
  end

  def initialize
    puts "initializing lab interface."
    $service = Google::Apis::ScriptV1::ScriptService.new
    $service.client_options.application_name = APPLICATION_NAME
    $service.authorization = authorize
  end

  # method overriden from adapter.
  # data should be an array of objects.
  # see adapter for the recommended structure.
  def update_LIS(data)

    orders = JSON.generate(data)

    pp = {
      :input => orders
    }

    request = Google::Apis::ScriptV1::ExecutionRequest.new(
      function: 'update_report',
      parameters: pp
    )

    ## here we have to have some kind of logging.
    ## should it be with redis / to a log file.
    ## logging is also sent to redis.
    ## at each iteration of the poller.

    begin
      puts "request is:"
      puts request.parameters.to_s
      puts $service.authorization.to_s
      resp = $service.run_script(SCRIPT_ID, request)

      if resp.error
        puts "there was an error."
      else
        puts "success"
      end
    rescue => e
      puts "error ----------"
      puts e.to_s
    end

  end

end