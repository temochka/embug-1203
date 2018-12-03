require 'ffi'

module EmbugB
	extend FFI::Library

	ffi_lib "#{File.dirname(__FILE__)}/libembugb/libembugb.so"

	attach_function :embugb_demo, [:int], :int
end

