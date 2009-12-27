require 'rubygems'
require 'mail'
require 'lib/mail_haxies'

TMP_OFFLINE_DIR = 'mails/_fetched/offline'
PARSED_DIR = 'mails/offline'

Dir["#{TMP_OFFLINE_DIR}/*.eml"].each do |eml|
  Mail.read(eml).save_attachments("#{PARSED_DIR}/#{eml.gsub(/\D/, '')}")
end
