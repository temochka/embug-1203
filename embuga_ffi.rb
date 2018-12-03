require 'ffi'

module EmbugA
	extend FFI::Library

	ffi_lib "#{File.dirname(__FILE__)}/libembuga/libembuga.so"

	attach_function :embuga_demo, [:int], :int
end

