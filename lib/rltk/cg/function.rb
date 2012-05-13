# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/04/06
# Description:	This file defines the Function class.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/cg/bindings'
require 'rltk/cg/basic_block'
require 'rltk/cg/value'

#######################
# Classes and Modules #
#######################

module RLTK::CG
	class Function < GlobalValue
		attr_reader :type
		
		def initialize(overloaded, name = '', *type_info, &block)
			@ptr =
			case overloaded
			when FFI::Pointer
				overloaded
			
			when RLTK::CG::Module
				@type = if type_info.first.is_a?(FunctionType) then type_info.first else FunctionType.new(*type_info) end
				
				Bindings.add_function(overloaded, name.to_s, @type)
				
			else
				raise 'The first argument to Function.new must be either a pointer or an instance of RLTK::CG::Module.'
			end
			
			self.instance_exec(self, &block) if block
		end
		
		def attributes
			@attributes ||= FunctionAttrCollection.new(self)
		end
		alias :attrs :attributes
		
		def basic_blocks
			@basic_blocks ||= BasicBlockCollection.new(self)
		end
		alias :blocks :basic_blocks
		
		def calling_convention
			Bindings.get_function_call_conv(@ptr)
		end
		
		def calling_convention=(conv)
			Bindings.set_function_call_conv(@ptr, conv)
			
			conv
		end
		
		def parameters
			@parameters ||= ParameterCollection.new(self)
		end
		alias :params :parameters
		
		def verify
			do_verification(:return_status)
		end
		
		def verify!
			do_verification(:abort_process)
		end
		
		def do_verification(action)
			Bindings.verify_function(@ptr, action).to_bool
		end
		private :do_verification
		
		class BasicBlockCollection
			include Enumerable
			
			def initialize(fun)
				@fun = fun
			end
			
			def append(name = '', context = nil, &block)
				BasicBlock.new(@fun, name, context, &block)
			end
			
			def each
				return to_enum :each unless block_given?
				
				ptr = Bindings.get_first_basic_block(@fun)
				
				self.size.times do |i|
					yield BasicBlock.new(ptr)
					ptr = Bindings.get_next_basic_block(ptr)
				end
			end
			
			def entry
				BasicBlock.new(Bindings.get_entry_basic_block(@fun))
			end
			
			def first
				if (ptr = Bindings.get_first_basic_block(@fun)) then BasicBlock.new(ptr) else nil end
			end
			
			def last
				if (ptr = Bindings.get_last_basic_block(@fun)) then BasicBlock.new(ptr) else nil end
			end
			
			def size
				Bindings.count_basic_blocks(@fun)
			end
		end
		
		class FunctionAttrCollection < AttrCollection
			@@add_method = :add_function_attr
			@@del_method = :remove_function_attr
		end
		
		class ParameterCollection
			include Enumerable
			
			def initialize(fun)
				@fun = fun
			end
			
			def [](index)
				index += self.size if index < 0
				
				if 0 <= index and index < self.size
					Value.new(Bindings.get_param(@fun, index))
				end
			end
			
			def each
				return to_enum :each unless block_given?
				
				self.size.times { |index| yield self[index] }
				
				self
			end
			
			def size
				Bindings.count_params(@fun)
			end
			
			def to_a
				self.size.times.to_a.inject([]) { |params, index| params << self[index] }
			end
		end
	end
end
