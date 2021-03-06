#!/usr/bin/env ruby

# A tool for summarizing outbound and inbound TCP connections.
#
# If you're having color problems I feel bad for you, son
# I got 99 problems but a 8-color term aint one
require 'set'

PROCESS_NAME_COLOR = 27
PROCESS_ID_COLOR = 131
PORT_COLOR = 110
CONNECTED_COLOR = 36
WAITING_TO_BE_CLOSED_COLOR = 181
CLOSED_COLOR = 244
LISTENING_COLOR = 69
COLON_COLOR = 255

class ConnectionInfo
  attr_accessor :listening_host,   :listening_port, 
                :destination_host, :destination_port,
                :state, :pid

  def initialize(listening_host, listening_port, destination_host, destination_port, state, pid, is_connected)
    @listening_host = listening_host 
    @listening_port = listening_port
    @destination_host = destination_host
    @destination_port = destination_port
    @state = state
    @pid = pid
    @is_connected = is_connected
  end

  def is_connected?
    return @is_connected
  end
end

class ProcessInfo
  attr_accessor :pid, :executable, :command
  attr_reader :connections

  def initialize(pid, command, executable)
    @pid, @command, @executable = pid, command, executable
    @connections = []
  end
end

def color_for_state(connection_state)
  if connection_state == '(established)'
    "\x1b[38;5;#{CONNECTED_COLOR}m"
  elsif ['(close_wait)', '(time_wait)'].include? connection_state 
    "\x1b[38;5;#{WAITING_TO_BE_CLOSED_COLOR}m"
  elsif connection_state == '(closed)'
    "\x1b[38;5;#{CLOSED_COLOR}m"
  else
    "\x1b[38;5;#{LISTENING_COLOR}m"
  end
end

def get_color(color_name)
  "\x1b[38;5;#{color_name}m"
end

def end_color()
  "\x1b[0m"
end

def plural_or_singular(number)
  if number == 1
    "connection"
  else 
    "connections"
  end
end

def get_console_output(process_list)
  console_output = ""
  connected_count = 0
  waiting_to_be_closed_count = 0
  closed_count = 0
  listening_count = Set.new

  # query processes by their port #
  listening_processes = {}
  process_list.each do |p|
    p.connections.each do |c|
      listening_processes[c.listening_port] = p.executable
    end
  end

  process_list.each do |process|
    process_id = process.pid
    process_name = process.executable

    console_output << get_color(PROCESS_NAME_COLOR)
    console_output << "#{process_name} "
    console_output << end_color
    console_output << "("
    console_output << get_color(PROCESS_ID_COLOR)
    console_output << process_id
    console_output << end_color
    console_output << ") "

    # uncomment to show full path of process    
    # if process_name != process.command
      # console_output << get_color(PROCESS_NAME_COLOR)
      # console_output << process.command
      # console_output << end_color
    # end
    
    console_output << "\r\n"

    unique_ports_per_process = Set.new 
    process.connections.sort_by! { |conn| conn.destination_host || ""}
    process.connections.each do |connection|
     
      if connection.is_connected?
        from_port        = connection.listening_port
        to               = connection.destination_host
        to_port          = connection.destination_port
        connection_state = connection.state.downcase

        if connection_state == '(established)'
          connected_count += 1
        elsif ['(close_wait)', '(time_wait)'].include? connection_state 
          waiting_to_be_closed_count += 1
        elsif connection_state == '(closed)'
          closed_count += 1
        end

        process_output = ""
        process_output << color_for_state(connection_state) << "  localhost" << end_color
        process_output << get_color(COLON_COLOR) << ":" << end_color
        process_output << color_for_state(connection_state) << from_port << end_color

        process_output << get_color(250) << " -> " << end_color

        process_output << color_for_state(connection_state)
        # print proc executable when a proc connects to another proc
        if to == "localhost" 
          if listening_processes.key?(to_port)
            process_output << listening_processes[to_port]
          end
        else
          process_output << to
        end
        process_output << get_color(COLON_COLOR)
        process_output << ":"
        process_output << get_color(65)
        process_output << to_port
        process_output << end_color
        
        if not ['(established)', '(close_wait)', '(closed)', '(time_wait)'].include? connection_state
          process_output << " #{connection_state}" 
        end
        
        process_output << "\r\n"
        console_output << process_output
      else
        listening_conn = connection.listening_host + connection.listening_port
        # Hide when a listening connection is listed twice, ex: *:22 
        # we just want to know that it IS listening
        if not unique_ports_per_process.include? listening_conn
          unique_ports_per_process.add(listening_conn)
          listening_count.add(connection.listening_port)
          
          process_output = ""

          process_output << get_color(LISTENING_COLOR)
          process_output << "  #{connection.listening_host}"
          process_output << end_color
          process_output << ":"
          process_output << get_color(LISTENING_COLOR)
          process_output << connection.listening_port
          process_output << end_color
        
          process_output << "\r\n" 
          console_output << process_output
        end 
      end
    end
  end

  console_output << "\r\n"
  # console_output << "\x1b[38;5;254mTCP connections:\x1b[0m\r\n"

  if listening_count.count
    console_output << "#{get_color(LISTENING_COLOR)}#{listening_count.count} listening#{end_color}, "
  end
  if waiting_to_be_closed_count > 0
    console_output << "#{get_color(WAITING_TO_BE_CLOSED_COLOR)}#{waiting_to_be_closed_count} closing#{end_color}, "
  end
  if closed_count > 0
    console_output << "#{get_color(CLOSED_COLOR)}#{closed_count} closed#{end_color}, "
  end
  if connected_count > 0
    console_output << "#{get_color(CONNECTED_COLOR)}#{connected_count} established#{end_color}"
  end

  return console_output
end

def parse_ps_output(ps_output)
  processes = []
  ps_output.lines.each do |line|
      line = line.strip() 
      split_pos = line.index(' ')
      pid = line[0..split_pos].strip()
      command = line[split_pos..-1].strip()
      executable = File.basename(command)
      processes << ProcessInfo.new(pid, command, executable)
  end
  return processes
end

def parse_lsof_output(lsof_output)
  process_connections = []

  lsof_output.lines.each do |line| 
    process_name, pid, user_name, file_descriptor, ip_type, device_id,
    size, node_type, connections, connection_state = line.split(' ') 
    
    if connections.include? "->"
      from, from_port, to, to_port = connections.split(/\:|\-\>/)
      process_connections << ConnectionInfo.new(from, from_port, to, to_port, connection_state, pid, true)
    else
      listening_host, listening_port = connections.split(':')
      process_connections << ConnectionInfo.new(listening_host, listening_port, nil, nil, connection_state, pid, false)
    end
  end

  return process_connections
end

def print_connections_by_process()
  process_list = parse_ps_output(`sudo ps -eo pid,comm`)
  connections = parse_lsof_output(`sudo lsof +c 0 -i -P | grep TCP`)
 
  connections = connections.group_by { |pc| pc.pid }
  process_list.each { |p| p.connections.push(*connections[p.pid]) }
  process_list.reject! { |p| p.connections.count == 0 }

  output = get_console_output(process_list)
  puts output
end

print_connections_by_process()

