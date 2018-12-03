#!/usr/bin/env ruby

require_relative './embugb_ffi'

puts EmbugB.embugb_demo(5).inspect;
puts EmbugB.embugb_demo(-1).inspect;
