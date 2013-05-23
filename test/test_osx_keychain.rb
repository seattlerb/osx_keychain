require "minitest/autorun"
require "osx_keychain"

CAN_TEST = ENV['SECURITYSESSIONID']

class TestOsxKeychain < Minitest::Test
  def test_sanity
    keychain = OSXKeychain.new

    serv, user, pass = %w[osx_keychain_test username password]

    keychain[serv, user] = pass

    assert_equal pass, keychain[serv, user]
    assert_equal pass, keychain[serv]
  end if CAN_TEST
end
