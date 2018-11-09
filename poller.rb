require 'rufus-scheduler'
require 'time'
require 'redis'

scheduler = Rufus::Scheduler.new

$redis = Redis.new

scheduler.every '3s' do
	puts $redis.lrange "patients",0,-1
end

scheduler.join
