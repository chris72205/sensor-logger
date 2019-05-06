require 'dotenv/load'
require "bunny"
require "json"
require "pg"

PG_HOST = ENV['PG_HOST']
PG_DB = ENV['PG_DB']
PG_PORT = ENV['PG_PORT']
PG_USER = ENV['PG_USER']
PG_PASS = ENV['PG_PASS']

# Create table if not exists
pg_conn = PG.connect(host: PG_HOST, port: PG_PORT, dbname: PG_DB, user: PG_USER, password: PG_PASS)
# pg_conn.exec("CREATE TABLE IF NOT EXISTS sensor_readings (id int PRIMARY_KEY, source text, temperature float, humidity float, timestamp DATETIME)")

# Output data and then insert into database
def log_data pg_conn, source, temperature, humidity
  puts "Logging #{source} with a T of #{temperature} and H of #{humidity}"

  pg_conn.exec("INSERT INTO sensor_readings (source, temperature, humidity, timestamp) VALUES('#{source}', #{temperature}, #{humidity}, NOW())")
end

AMQP_HOST = ENV['AMQP_HOST']
AMQP_VHOST = ENV['AMQP_VHOST']
AMQP_USER = ENV['AMQP_USER']
AMQP_PASS = ENV['AMQP_PASS']

# Connect to rabbitmq
conn = Bunny.new host: AMQP_HOST, user: AMQP_USER, pass: AMQP_PASS, vhost: AMQP_VHOST
conn.start

# Declare channel, exchange, queue
ch = conn.create_channel
ex = ch.topic('amq.topic')
q = ch.queue("temp-humidity-readings", exclusive: false, durable: true, arguments: {'x-message-ttl' => 1000})

# Bind queue to topic
q.bind(ex, routing_key: 'sensor.th-readings')
q.subscribe(block: true) do |delivery_info, properties, raw_payload|
  # puts "Delivery Info: #{delivery_info}"
  # puts "Properties: #{properties}"
  # puts "Payload: #{payload}"

  payload = JSON.parse raw_payload

  temp = payload['t']
  humidity = payload['h']
  source = payload['s']


  log_data(pg_conn, source, temp, humidity)

  (1..3).each{|n| puts ""}
end
