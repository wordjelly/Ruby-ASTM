require 'rubygems'
require 'eventmachine'
require "active_support/all"
require "/home/bhargav/Github/ruby_astm/line"
require "/home/bhargav/Github/ruby_astm/frame"
require "/home/bhargav/Github/ruby_astm/record"
require "/home/bhargav/Github/ruby_astm/lab_interface"
require "/home/bhargav/Github/ruby_astm/header"
require "/home/bhargav/Github/ruby_astm/patient"
require "/home/bhargav/Github/ruby_astm/record"

include LabInterface

$SERVER_IP = "192.168.1.11"
$SERVER_PORT = "3000"
$ENQ = "[5]"
$start_text = "[2]"
$end_text = "[3]"
$record_end = "[13]"
$frame_end = "[10]"

=begin
EventMachine.run {
  EventMachine::start_server $SERVER_IP, $SERVER_PORT, LabInterface
  puts "running echo server on #{$SERVER_PORT}"
}
=end


IO.read("sample.txt").each_line do |l|
	process_text(l)
end
