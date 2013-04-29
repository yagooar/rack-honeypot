require 'rack/test'
require 'test/unit'
require 'mocha/setup'
require 'unindentable'

require File.expand_path(File.dirname(__FILE__) + '/../lib/rack/honeypot')

# To run this test, you need to have rack-test gem installed: sudo gem install rack-test

class HoneypotTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include Unindentable

  def setup
    @logger = stub("logger", :warn => nil)
    @always_enabled = true
    @honeypot_header = nil
  end

  def app
    content = unindent <<-BLOCK
      <html>
        <head>
        </head>
        <body>
          <form></form>
          Hello World!
        </body>
      </html>
    BLOCK

    headers = {
      'Content-Type'   => 'text/plain',
      'Content-Length' => content.length.to_s,
    }

    headers['X-Honeypot'] = @honeypot_header if @honeypot_header

    hello_world_app = lambda {|env| [200, headers, [content]] }

    Rack::Honeypot.new(hello_world_app, :input_name => 'honeypot_email', :logger => @logger, :always_enabled => @always_enabled)
  end

  def test_normal_request_should_go_through
    get '/'
    assert_equal 200, last_response.status
    assert_not_equal '', last_response.body
  end

  def test_request_with_form_should_add_honeypot_container
    get '/'
    assert_equal 200, last_response.status

    assert includes_honeypot?
    assert includes_style?
  end

  def test_spam_request_should_be_sent_to_dead_end
    post '/', :honeypot_email => 'joe@example.com'
    assert_equal 200, last_response.status
    assert_equal '', last_response.body
  end

  def test_spam_request_should_be_logged
    @logger.expects(:warn).with("[Rack::Honeypot] Spam bot detected; responded with null")
    post '/', :honeypot_email => 'joe@example.com'
  end

  def test_should_not_inject_honeypot_if_not_always_enabled
    @always_enabled = false

    get '/'

    assert_equal 200, last_response.status
    assert !includes_honeypot?
    assert !includes_style?
  end

  def test_should_inject_honeypot_if_not_always_enabled_but_honeypot_header_present
    @always_enabled = false
    @honeypot_header = "enabled"

    get '/'

    assert_equal 200, last_response.status
    assert includes_honeypot?
    assert includes_style?
  end

  def test_custom_container_honored
    @container = 'div'

    get '/'

    assert_equal 200, last_response.status
    assert includes_custom_container?
  end

  private

  def includes_honeypot?
    container = unindent <<-BLOCK
      <span class='phonetoy' style='display: none;'>
        <label for='honeypot_email'>Don't fill in this field</label>
        <input type='text' name='honeypot_email' value=''/>
      </span>
    BLOCK

    last_response.body.index(container) != nil
  end

  def includes_custom_container?
    last_response.body.index('span') != nil
  end

  def includes_style?
    last_response.body.index("style='display: none;'") != nil
  end

end
