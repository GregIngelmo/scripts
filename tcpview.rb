#!/usr/bin/env ruby

# A tool for summarizing outbound and inbound TCP connections.
# If you don't have a 256 color terminal I feel bad for you son, 
# I got 99 problems and an 8-color-terminal ain't one.
require 'set'

PROCESS_NAME_COLOR = 27
PORT_COLOR = 110
CONNECTED_COLOR = 36
WAITING_TO_BE_CLOSED_COLOR = 181
CLOSED_COLOR = 244
LISTENING_COLOR = 69
COLON_COLOR = 255


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

def get_console_output(lines_grouped)
  console_output = ""
  connected_count = 0
  waiting_to_be_closed_count = 0
  closed_count = 0
  listening_count = Set.new

  lines_grouped.each do |process_name, process_connections|
    console_output << "\x1b[38;5;#{PROCESS_NAME_COLOR}m"
    console_output << "#{process_name} (#{process_connections[0][1]})"
    console_output << "\x1b[0m\r\n"

    process_connections.sort! do |a,b|
      a[-2] <=> b[-2]
    end
    
    unique_ports_per_process = Set.new 
    process_connections.each do |process_connection|
      # unpack the list 
      process_name, pid, user_name, file_descriptor, ip_type, device_id,
      size, node_type, connections, connection_state = process_connection

      connection_state = connection_state.downcase()
      connections = process_connection[-2]
     
      if connections.include? "->"
        from, from_port, to, to_port = connections.split(/\:|\-\>/)
       
        # ignore connections from localhost to localhost from the same process
        if from.include? 'localhost' and to.include? 'localhost'
          next
        end

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
        process_output << to
        process_output << get_color(COLON_COLOR)
        process_output << ":"
        process_output << color_for_state(connection_state)
        process_output << to_port
        process_output << end_color
        
        if not ['(established)', '(close_wait)', '(closed)', '(time_wait)'].include? connection_state
          process_output << " #{connection_state}" 
        end
        
        process_output << "\r\n"
        console_output << process_output
      else
        host_name, port = connections.split(':')

        if not unique_ports_per_process.include? port
          unique_ports_per_process.add(port)
          listening_count.add(port)
          
          process_output = ""

          process_output << get_color(LISTENING_COLOR)
          process_output << "  #{host_name}"
          process_output << end_color
          process_output << ":"
          process_output << get_color(LISTENING_COLOR)
          process_output << port
          process_output << end_color
        
          process_output << "\r\n" 
          console_output << process_output
        end 
      end
    end
  end

  console_output << "\r\n"
  console_output << "\x1b[38;5;254mConnections:\x1b[0m\r\n"

  if connected_count > 0
    console_output << "  #{get_color(CONNECTED_COLOR)}#{connected_count} established #{end_color}\r\n"
  end
  if waiting_to_be_closed_count > 0
    console_output << "  #{get_color(WAITING_TO_BE_CLOSED_COLOR)}#{waiting_to_be_closed_count} closing #{end_color}\r\n"
  end
  if closed_count > 0
    console_output << "  #{get_color(CLOSED_COLOR)}#{closed_count} closed \x1b[0m\r\n"
  end
  if listening_count.count
    console_output << "  #{get_color(LISTENING_COLOR)}#{listening_count.count} ports open \x1b[0m"
  end

  return console_output
end

def print_connections_by_process()
  lsof_result = `sudo lsof +c 0 -i -P | grep TCP`
  #ps_result = `ps -eo pid,comm`
  lines = lsof_result.lines.collect { |line| line.split(' ') }
  lines_grouped = lines.group_by { |line| line[0] }

  output = get_console_output(lines_grouped)
  puts output
end

print_connections_by_process()
