#!/usr/bin/env ruby

require_relative './embugb_ffi'
require_relative './embuga_ffi'
require 'rubyeventmachine'

puts EmbugB.embugb_demo(5).inspect;
puts EmbugB.embugb_demo(-1).inspect;
puts EmbugA.embuga_demo(5).inspect;
puts EmbugA.embuga_demo(-1).inspect;

