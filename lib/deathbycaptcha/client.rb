require 'logger'
require 'digest/sha1'
require 'rest_client'

module DeathByCaptcha
  
  #
  # DeathByCaptcha API Client
  #
  class Client
    
    attr_accessor :config
    
    def initialize(username, password, extra={})
      data = {
        :is_verbose => false, # If true, prints messages during execution
        :logger_output => STDOUT, # Logger output path or IO instance
        :api_version => API_VERSION, # API version (used as user-agent with http requests)
        :software_vendor_id => 0, # API unique software ID
        :max_captcha_file_size => 64 * 1024, # Maximum CAPTCHA image filesize, currently 64K
        :default_timeout => 60, # Default CAPTCHA timeout
        :polls_interval => 5, # Default decode polling interval
        :http_base_url => 'http://api.deathbycaptcha.com/api', # Base HTTP API url
        :http_response_type => 'application/json', # Preferred HTTP API server's response content type, do not change
        :socket_host => 'api.deathbycaptcha.com', # Socket API server's host
        :socket_port => (8123..8130).map {|p| p}, # Socket API server's ports range
        :username => username, # DeathByCaptcha username
        :password_hashed => Digest::SHA1.hexdigest(password), # DeathByCaptcha user's password encrypted
        :password => '', # DeathByCaptcha user's password not encrypted
        :password_is_hashed => true # True, if the password is hashed
      }.merge(extra)
      
      @config = DeathByCaptcha::Config.new(data) # Config instance
      @logger = Logger.new(@config.logger_output) # Logger
      
    end
    
    #
    # Fetch the user's details -- balance, rate and banned status
    #
    def get_user
      raise DeathByCaptcha::Errors::NotImplemented
    end
    
    #
    # Fetch the user's balance (in US cents)
    #
    def get_balance
      raise DeathByCaptcha::Errors::NotImplemented
    end
    
    #
    # Fetch a CAPTCHA details -- its numeric ID, text and correctness
    #
    def get_captcha(cid)
      raise DeathByCaptcha::Errors::NotImplemented
    end
    
    #
    # Fetch a CAPTCHA text
    #
    def get_text(cid)
      raise DeathByCaptcha::Errors::NotImplemented
    end
    
    #
    # Report a CAPTCHA as incorrectly solved
    #
    def report(cid)
      raise DeathByCaptcha::Errors::NotImplemented
    end
    
    #
    # Remove an unsolved CAPTCHA
    #
    def remove(cid)
      raise DeathByCaptcha::Errors::NotImplemented
    end
    
    #
    # Upload a CAPTCHA
    #
    # Accepts file names, file objects or urls, and an optional flag telling
    # whether the CAPTCHA is case-sensitive or not.  Returns CAPTCHA details
    # on success.
    #
    def upload(captcha, is_case_sensitive=false)
      raise DeathByCaptcha::Errors::NotImplemented
    end
    
    #
    # Try to solve a CAPTCHA.
    #
    # See Client.upload() for arguments details.
    #
    # Uploads a CAPTCHA, polls for its status periodically with arbitrary
    # timeout (in seconds).  Removes unsolved CAPTCHAs.  Returns CAPTCHA
    # details if (correctly) solved.
    #
    def decode(captcha, timeout=@config.default_timeout, is_case_sensitive=false)
      deadline = Time.now + timeout
      c = upload(captcha, is_case_sensitive)
      if c
        while deadline > Time.now and not c['text']
          sleep(config.polls_interval)
          c = get_captcha(c['captcha'])
        end
        
        if c['text']
          if c['is_correct']
            return c
          end
        else
          remove(c['captcha'])
        end
        
      end
      
      
    end
    
    protected
    #
    # Return a hash with the user's credentials
    #
    def userpwd
      if config.password_is_hashed
        return {:username => config.username, :password => config.password_hashed, :is_hashed => '1'}
      else
        return {:username => config.username, :password => config.password}
      end
    end
    
    private
    #
    # Log a command and a message
    #
    def log(cmd, msg='')
      if @config.is_verbose
        @logger.info msg
      end
    end

    #
    # Return the File instance that corresponds to the captcha
    #
    # captcha can be:
    # => a raw file content if is_raw_content is true
    # => a File if its kind of File
    # => a url if it's a String and starts with 'http://'
    # => a filesystem path otherwise
    #
    def load_file(captcha, is_raw_content=false)
      file = nil
      if is_raw_content
        # Create a temporary file, write the raw content and return it
        tmp_file_path = File.join(Dir.tmpdir, "captcha_#{Time.now.to_i}_#{rand}")
        File.open(tmp_file_path, 'w') {|f| f.write captcha}
        file = File.open(tmp_file_path, 'r')
        
      elsif captcha.kind_of? File
        # simply return the file
        file = captcha
        
      elsif captcha.kind_of? String and captcha[0,7] == 'http://'
        # Create a temporary file, download the file, write it to tempfile and return it
        tmp_file_path = File.join(Dir.tmpdir, "captcha_#{Time.now.to_i}_#{rand}")
        File.open(tmp_file_path, 'w') {|f| f.write RestClient.get(captcha)}
        file = File.open(tmp_file_path, 'r')
        
      else
        # Return the File opened
        file = File.open(captcha, 'r')
        
      end
      
      if file.nil?
        raise DeathByCaptcha::Errors::CaptchaEmpty
      elsif config.max_captcha_file_size <= file.size
        raise DeathByCaptcha::Errors::CaptchaOverflow
      end
      
      return file
    end
    
  end
  
end