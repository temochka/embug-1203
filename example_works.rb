#!/usr/bin/env ruby

require 'rubyeventmachine'
require_relative './embug_ffi'

puts Embug.embug_demo(5).inspect;
puts Embug.embug_demo(-1).inspect;
