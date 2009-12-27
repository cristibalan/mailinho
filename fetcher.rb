require 'settings'
require 'fileutils'

require 'rubygems'
require 'gmail'

TMP_INBOX_DIR = 'mails/_fetched/inbox'
TMP_OFFLINE_DIR = 'mails/_fetched/offline'

gmail = Gmail.new(USERNAME, PASSWORD)

# fetch all emails into TMP_INBOX_DIR and move them to the offline label
FileUtils.mkdir_p(TMP_INBOX_DIR)
gmail.inbox.emails.each do |email|
  filename = "#{TMP_INBOX_DIR}/#{email.uid}.eml"
  p "#{email.message.from}: #{email.message.subject}"
  

  p "saving to #{filename}"
  if File.exist? filename
    p "#{filename} already exists. not saving again"
    next
  else
    File.open(filename, "w") do |f|
      f << email.body
    end
    p "saved"
  end

  p "moving to 'offline'"
  email.mark(:read)
  email.move_to('offline')
  p "done"
end

# move all emails from TMP_INBOX_DIR into TMP_OFFLINE_DIR with the correct new uid from the offline label
gmail.in_mailbox(gmail.mailbox('offline')) do 
  Dir["#{TMP_INBOX_DIR}/*.eml"].each do |eml|
    p "moving #{eml}"

    message_id = File.readlines(eml).grep(/^message-id: /i)[0].split(': ')[1]
    new_uid = nil
    new_uid = gmail.imap.uid_search(['HEADER', 'Message-ID', message_id])[0]
    unless new_uid
      p "could not get new_uid for #{message_id}"
      next
    end

    new_filename = "#{TMP_OFFLINE_DIR}/#{new_uid}.eml"

    p "moving #{eml} to #{new_filename}"
    if File.exist? new_filename
      p "#{new_filename} already exists. not moved"
      next
    end

    FileUtils.mv(eml, new_filename)
    p "moved"
  end
end
