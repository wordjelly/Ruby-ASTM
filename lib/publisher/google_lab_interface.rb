require 'google/apis/script_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'

class Google_Lab_Interface < Adapter

  ## WRITTEN BY A DOCTOR ;}
=begin

=end
  EDTA = "EDTA"
  SERUM = "SERUM"
  PLASMA = "PLASMA"
  FLUORIDE = "FLUORIDE"
  ESR = "ESR"
  URINE = "URINE"

  REQUISITIONS_SORTED_SET = "requisitions_sorted_set"
  REQUISITIONS_HASH = "requisitions_hash"

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

  def root_path
    File.dirname __dir__
  end

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
    AstmServer.log("Initialized Google Lab Interface")
    $service = Google::Apis::ScriptV1::ScriptService.new
    $service.client_options.application_name = APPLICATION_NAME
    $service.authorization = authorize
    ## this mapping is from MACHINE CODE AS THE KEY
    $mappings = JSON.parse(IO.read(mpg || ("mappings.json")))
    ## INVERTING THE MAPPINGS, GIVES US THE LIS CODE AS THE KEY.
    $inverted_mappings = Hash[$mappings.values.map{|c| c = c["LIS_CODE"]}.zip($mappings.keys)]
  end

  def build_tests_hash(record)
    tests_hash = {}

    ## key -> TUBE_NAME : eg: EDTA
    ## value -> its barcode id.
    tube_ids = {}
    ## assign.
    ## lavender -> index 28
    ## serum -> index 29
    ## plasm -> index 30
    ## fluoride -> index 31
    ## urine -> index 32
    ## esr -> index 33
    unless record[28].blank?
      tube_ids[EDTA] = record[28]
      tests_hash[EDTA + ":" + record[28]] = []
    end

    unless record[29].blank?
      tube_ids[SERUM] = record[29]
      tests_hash[SERUM + ":" + record[29]] = []
    end

    unless record[30].blank?
      tube_ids[PLASMA] = record[30]
      tests_hash[PLASMA + ":" + record[30]] = []
    end

    unless record[31].blank?
      tube_ids[FLUORIDE] = record[31]
      tests_hash[FLUORIDE + ":" + record[31]] = []
    end

    unless record[32].blank?
      tube_ids[URINE] = record[32]
      tests_hash[URINE + ":" + record[32]] = []
    end

    unless record[33].blank?
      tube_ids[ESR] = record[33]
      tests_hash[ESR + ":" + record[33]] = []
    end


    tests = record[8].split(",")
    tests.each do |test|
      ## use the inverted mappings to 
      if machine_code = $inverted_mappings[test]
        ## now get its tube type
        ## mappings have to match the tubes defined in this file.
        tube = $mappings[machine_code]["TUBE"]
        ## now find the tests_hash which has this tube.
        ## and the machine code to its array.
        ## so how to find this.
        tube_key = tests_hash.keys.select{|c| c=~/#{tube}/ }[0] 
        tests_hash[tube_key] << machine_code   
      else
        AstmServer.log("ERROR: Test: #{test} does not have an LIS code")
      end 
    end
    AstmServer.log("tests hash generated")
    AstmServer.log(JSON.generate(tests_hash))
    tests_hash
  end

  ## @param[Integer] epoch : the epoch at which these tests were requested.
  ## @param[Hash] tests : {"EDTA:barcode" => [MCV,MCH,MCHC...]}
  def merge_with_requisitions_hash(epoch,tests)
    ## so we basically now add this to the epoch ?
    ## or a sorted set ?
    ## key -> TUBE:specimen_id
    ## value -> array of tests as json
    ## score -> time.
    $redis.multi do |multi|
      $redis.zadd REQUISITIONS_SORTED_SET, epoch, JSON.generate(tests)
      tests.keys.each do |tube_barcode|
        $redis.hset REQUISITIONS_HASH, tube_barcode, JSON.generate(tests[tube_barcode])
      end  
    end
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
        lab_results = JSON.parse(resp.response["result"])
        AstmServer.log("lab resuls downloaded from Google Drive")
        AstmServer.log(JSON.generate(lab_results))
        lab_results.keys.each do |epoch|
          merge_with_requisitions_hash(epoch,build_tests_hash(lab_results[epoch][0]))
        end
        AstmServer.log("Successfully polled lis for requisitions: #{resp.response}")
      end
    rescue => e
      AstmServer.log("Rescue Error polling LIS for requisitions: #{e.to_s}")
      AstmServer.log("Error backtrace")
      AstmServer.log(e.backtrace.to_s)
    end
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