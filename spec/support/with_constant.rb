def split_constant_string(const_string)
  parent_constant = const_string.to_s.split("::")[0..-2].inject(Object) { |o, c| o.const_get(c) }
  child_constant = const_string.to_s.split("::").last
  [parent_constant, child_constant]
end

def with_constants(constants, &block)
  saved_constants = {}
  constants.each_pair do |constant, val|
    parent, child = split_constant_string(constant)
    saved_constants[ constant ] = parent.const_get( child )
    with_warnings(nil) { parent.const_set( child, val ) }
  end

  begin
    block.call
  ensure
    constants.each_pair do |constant, val|
      parent, child = split_constant_string(constant)
      with_warnings(nil) { parent.const_set( child, saved_constants[ constant ] ) }
    end
  end
end
