require 'google/apis/script_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
require 'publisher/poller'

class Google_Lab_Interface < Poller


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

    client_id = Google::Auth::ClientId.from_file(root_path + "/publisher/" + CREDENTIALS_PATH)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: (root_path + "/publisher/" + TOKEN_PATH))
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

  ## @param[String] mpg : path to mappings file. Defaults to nil.
  def initialize(mpg=nil)
    super(mpg)
    AstmServer.log("Initialized Google Lab Interface")
    $service = Google::Apis::ScriptV1::ScriptService.new
    $service.client_options.application_name = APPLICATION_NAME
    $service.authorization = authorize
  end


  def poll_LIS_for_requisition
    
    
     
    AstmServer.log("polling LIS for new requisitions")
    
    epoch = (Time.now - 5.days).to_i*1000
    
    pp = {
      :input => JSON.generate([epoch])
    }

    request = Google::Apis::ScriptV1::ExecutionRequest.new(
      function: 'get_latest_test_information',
      parameters: pp
    )

    begin 
      resp = $service.run_script(SCRIPT_ID, request)
      if resp.error
        AstmServer.log("Response Error polling LIS for requisitions: #{resp.error.message}: #{resp.error.code}")
      else
        process_LIS_response(resp.response["result"])
        AstmServer.log("Successfully polled lis for requisitions: #{resp.response}")
      end
    rescue => e
      AstmServer.log("Rescue Error polling LIS for requisitions: #{e.to_s}")
      AstmServer.log("Error backtrace")
      AstmServer.log(e.backtrace.to_s)
    ensure
      
    end

  end


  # method overriden from adapter.
  # data should be an array of objects.
  # see adapter for the recommended structure.
  def update(data)

    orders = JSON.generate(data)

    pp = {
      :input => orders
    }

    request = Google::Apis::ScriptV1::ExecutionRequest.new(
      function: 'update_report',
      parameters: pp
    )

    begin
      AstmServer.log("updating following results to LIS")
      AstmServer.log(request.parameters.to_s)
      resp = $service.run_script(SCRIPT_ID, request)
      if resp.error
        AstmServer.log("Error updating results to LIS, message follows")
        AstmServer.log("error: #{resp.error.message} : code: #{resp.error.code}")
        #puts "there was an error."
      else
        AstmServer.log("Updating results to LIS successfull")
      end
    rescue => e
      AstmServer.log("Error updating results to LIS, backtrace follows")
      AstmServer.log(e.backtrace.to_s)
    end

  end

  def poll
    super
  end

end