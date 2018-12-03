#!/usr/bin/env ruby

require_relative './embuga_ffi'

puts EmbugA.embuga_demo(5).inspect;
puts EmbugA.embuga_demo(-1).inspect;
