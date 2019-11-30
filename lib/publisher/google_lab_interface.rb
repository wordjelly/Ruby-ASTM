require 'google/apis/script_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
require_relative "poller"

class Google_Lab_Interface < Poller

  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'.freeze
  APPLICATION_NAME = 'Google Apps Script API Ruby Quickstart'.freeze
  ## these two cannot be hardcoded.
  #CREDENTIALS_PATH = 'credentials.json'.freeze
  #TOKEN_PATH = 'token.yaml'.freeze
  SCOPE = 'https://www.googleapis.com/auth/script.projects'.freeze

  SCOPES = ["https://www.googleapis.com/auth/documents","https://www.googleapis.com/auth/drive","https://www.googleapis.com/auth/script.projects","https://www.googleapis.com/auth/spreadsheets","https://www.googleapis.com/auth/script.external_request"]

  $service = nil

  attr_accessor :credentials_path
  attr_accessor :token_path
  attr_accessor :script_id
  
  ##
  # Ensure valid credentials, either by restoring from the saved credentials
  # files or intitiating an OAuth2 authorization. If authorization is required,
  # the user's default browser will be launched to approve the request.
  #
  # @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
  def authorize
    client_id = Google::Auth::ClientId.from_file(self.credentials_path)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: self.token_path)
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
  ## @param[String] credentials_path : the path to look for the credentials.json file, defaults to nil ,and will raise an error unless provided
  ## @param[String] token_path : the path where the oauth token will be stored, also defaults to the path of the gem : eg. ./token.yaml - be careful with write permissions, because token.yaml gets written to this path after the first authorization.
  def initialize(mpg=nil,credentials_path,token_path,script_id,real_time_db)
    super(mpg,real_time_db)
    self.credentials_path = credentials_path
    self.token_path = token_path
    self.script_id = script_id
    raise "Please provide the full path of the google oauth credentials.json file. If you don't have this file, please go to the Apps Script project, which has your google apps script, and Choose Create Credentials -> help me choose -> and use 'Calling Scripts Api from a UI based platform'. Also ensure that your script has permissions set for Drive, Sheets, and more. Lastly in the Apps script project ensure that settings -> google apps script API is ON." if self.credentials_path.nil?
    raise "Please provide a script id for your google script" if self.script_id.blank?
    AstmServer.log("Initialized Google Lab Interface")
    $service = Google::Apis::ScriptV1::ScriptService.new
    $service.client_options.application_name = APPLICATION_NAME
    $service.client_options.send_timeout_sec = 1200
    $service.client_options.open_timeout_sec = 1200
    $service.request_options.retries = 3
    $service.authorization = authorize
  end

  ## how to decide for what to poll for the requisition.
  ## this should be tested.
  def poll_LIS_for_requisition
    
    AstmServer.log("polling LIS for new requisitions")
    
    epoch = get_checkpoint
    
    pp = {
      :input => JSON.generate([epoch])
    }



    request = Google::Apis::ScriptV1::ExecutionRequest.new(
      function: 'get_latest_test_information',
      parameters: pp
    )

    puts "params are: #{pp}"

    #begin 
      resp = $service.run_script(self.script_id, request)
      if resp.error
        AstmServer.log("Response Error polling LIS for requisitions: #{resp.error.message}: #{resp.error.code}")
      else
        process_LIS_response(resp.response["result"])
        AstmServer.log("Successfully polled lis for requisitions: #{resp.response}")
      end
    #rescue => e
      #AstmServer.log("Rescue Error polling LIS for requisitions: #{e.to_s}")
      #AstmServer.log("Error backtrace")
      #AstmServer.log(e.backtrace.to_s)
    #ensure
      
    #end

  end


  # method overriden from adapter.
  # data should be an array of objects.
  # see adapter for the recommended structure.
  # @return[Boolean] true/false : depending on if there was an error or not.
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
      resp = $service.run_script(self.script_id, request)
      if resp.error
        AstmServer.log("Error updating results to LIS, message follows")
        AstmServer.log("error: #{resp.error.message} : code: #{resp.error.code}")
        false
      else
        AstmServer.log("Updating results to LIS successfull")
        true
      end
    rescue => e
      AstmServer.log("Error updating results to LIS, backtrace follows")
      AstmServer.log(e.backtrace.to_s)
      false
    end

  end

  ## sends emails of report pdfs to patients 
  def notify_patients
    request = Google::Apis::ScriptV1::ExecutionRequest.new(
      function: 'process_email_log'
    )

    begin
      AstmServer.log("Processing Email Log")
      AstmServer.log(request.parameters.to_s)
      resp = $service.run_script(self.script_id, request)
      if resp.error
        AstmServer.log("Error Processing Email Log, message follows")
        AstmServer.log("error: #{resp.error.message} : code: #{resp.error.code}")
        false
      else
        AstmServer.log("Email log processing successfull")
        true
      end
    rescue => e
      AstmServer.log("Error processing email log, backtrace follows")
      AstmServer.log(e.backtrace.to_s)
      false
    end
  end

  def poll
      pre_poll_LIS
      poll_LIS_for_requisition
      update_LIS
      notify_patients
      post_poll_LIS
  end

end