#\ -p 9999

use Rack::ShowExceptions

require 'mailinho'
run Mailinho::App
