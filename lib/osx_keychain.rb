#!/usr/bin/ruby -w

require 'rubygems'
require 'inline'

class OSXKeychain
  VERSION = '1.0.2'

  def []= service, username, password
    set(service, username, password)
  end

  def [] service, username = nil
    get(service, username)
  end

  inline :C do |builder|
    builder.include '<Security/Security.h>'

    builder.add_link_flags %w[-lc]

    builder.add_link_flags %w[-framework Security
                              -framework CoreFoundation
                              -framework CoreServices]

    builder.c <<-EOC
      VALUE get(char * service, VALUE _username) {
        char *username = RTEST(_username) ? StringValueCStr(_username) : NULL;
        OSStatus status;
        UInt32 length;
        CFArrayRef keychains = NULL;
        void *data;
        VALUE result = Qnil;

        status = SecKeychainCopySearchList(&keychains);

        if (status)
          rb_raise(rb_eRuntimeError,
                   "can't access keychains, Authorization failed: %d", status);

        status = SecKeychainFindGenericPassword(keychains,
                   (UInt32)strlen(service), service,
                   username ? (UInt32)strlen(username) : 0, username,
                   &length, &data, NULL);

        if (status == errSecItemNotFound)
          status = SecKeychainFindInternetPassword(keychains,
                     (UInt32)strlen(service), service,
                     0, NULL,
                     username ? (UInt32)strlen(username) : 0, username,
                     0, NULL, 0, kSecProtocolTypeAny, kSecAuthenticationTypeAny,
                     &length, &data, NULL);

        switch (status) {
          case 0:
            result = rb_str_new(data, length);
            SecKeychainItemFreeContent(NULL, data);
            break;
          case errSecItemNotFound:
            // do nothing, return nil password
            break;
          default:
            rb_raise(rb_eRuntimeError, "Can't fetch password from system");
            break;
        }

        CFRelease(keychains);

        return result;
      }
    EOC

    builder.c <<-EOC
      void set(char * service, char * username, char * password) {
        OSStatus status;
        SecKeychainRef keychain;
        SecKeychainItemRef item;

        status = SecKeychainOpen("login.keychain",&keychain);

        if (status)
          rb_raise(rb_eRuntimeError,
                   "can't access keychains, Authorization failed: %d", status);

        status = SecKeychainFindGenericPassword(keychain,
                   (UInt32)strlen(service), service,
                   username == NULL ? 0 : (UInt32)strlen(username), username,
                   0, NULL, &item);

        switch (status) {
          case 0:
            status = SecKeychainItemModifyAttributesAndData(item, NULL,
                       (UInt32)strlen(password), password);
            CFRelease(item);
            break;
          case errSecItemNotFound:
            status = SecKeychainAddGenericPassword(keychain,
                       (UInt32)strlen(service), service,
                       username == NULL ? 0 : (UInt32)strlen(username), username,
                       (UInt32)strlen(password), password,
                       NULL);
            break;
          default:
            rb_raise(rb_eRuntimeError, "Can't fetch password from system");
            break;
        }

        if (status)
          rb_raise(rb_eRuntimeError, "Can't store password in Keychain");
      }
    EOC
  end
end
