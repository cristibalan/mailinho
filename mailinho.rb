require 'sinatra/base'
require 'iconv'

require 'mail'
require 'parser'

require 'settings'
require 'fileutils'
require 'gmail'

MAIL_DIR = 'mails/offline'
TO_ARCHIVE_DIR = 'mails/to_archive'

module Enumerable
  # http://anarchaia.org/archive/2007/12/15.html
  def human_order_sort
    sort_by { |item| item.to_s.split(/(\d+)/).map { |e| [e.to_i, e] } }
  end
end

module Helpers
  include Rack::Utils
  alias :h :escape_html

  def link_to(title, url)
    %(<a href="#{url}">#{h(title)}</a>).html_safe!
  end

  def safe_html(html)
    html.gsub!('eval', '____eval')
    html.gsub!('javascript', '____javascript')
    html
  end
end

module Mailinho
  class Mail
    def initialize(eml)
      @mail = ::Mail.read(eml)
    end

    def self.decode(str)
      ::Mail::Encodings.unquote_and_convert_to(str, 'UTF8')
    end

    def decode(str)
      self.class.decode(str)
    end

    def method_missing(meth, *args)
      if meth.to_s =~ /^original_/
        @mail.send(meth.to_s.gsub(/^original_/, ''), *args)
      elsif respond_to? meth
        meth(*args)
      else
        @mail.send(meth, *args)
      end
    end

    def subject
      decode(@mail.subject.value)
    rescue
      'FAIL'
    end

    def from
      address, *name = @mail.from.formatted.first.split(' ').reverse
      name = name.reverse.join(' ')
      name = address if name.blank?

      [decode(name), address]
    rescue
      ['FAIL', 'FAIL']
    end

    def to
      @mail.to.formatted.map {|a| decode(a)}.join(", ")
    rescue
      'FAIL'
    end
  end

  class App < Sinatra::Default
    helpers Helpers
    set :public, File.dirname(__FILE__) + '/public'

    get '/' do
      @mails = Dir["#{MAIL_DIR}/*.eml"].human_order_sort.reverse.map{ |eml| [eml.gsub(/\D/, ''), Mail.new(eml)] }
      erb :index
    end

    get %r{/mails/(\d+)$} do |uid|
      @mail = Mail.new("#{MAIL_DIR}/#{uid}.eml")
      @uid = uid
      erb :show
    end

    get %r{/mails/(\d+)/body} do |uid|
      @mail = Mail.new("#{MAIL_DIR}/#{uid}.eml")
      @uid = uid
      erb :body, :layout => false
    end

    post %r{/mails/(\d+)} do |uid|
      uid = uid.to_i
      action = params["action"]

      gmail = Gmail.new(USERNAME, PASSWORD)
      offline = gmail.mailbox('offline')
      email = Gmail::Message.new(gmail, offline, uid)

      case action
      when 'archive'
        email.move_to('to_archive')
        FileUtils.mkdir_p("#{TO_ARCHIVE_DIR}")
        FileUtils.mv("#{MAIL_DIR}/#{uid}.eml", "#{TO_ARCHIVE_DIR}/#{uid}.eml")
      when 'delete'
        email.delete!
        FileUtils.rm("#{MAIL_DIR}/#{uid}.eml")
      when 'spam'
        email.mark(:spam)
        FileUtils.rm("#{MAIL_DIR}/#{uid}.eml")
      end

      redirect back
    end

    get '/compose' do
      @uid = params[:reply_to]
      @mail = @uid && Mail.new("#{MAIL_DIR}/#{@uid}.eml")
      @back = request.referer
      erb :compose
    end

    post '/send' do
      @uid = params[:reply_to]
      @mail = @uid && Mail.new("#{MAIL_DIR}/#{@uid}.eml")
      @back = params[:back]

      gmail = Gmail.new(USERNAME, PASSWORD)
      redirect params['back'] || '/'
    end
  end
end
