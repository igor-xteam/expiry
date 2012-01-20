$LOAD_PATH << File.dirname(__FILE__) unless $LOAD_PATH.include?(File.dirname(__FILE__))
Dir[File.join(File.dirname(__FILE__),'tasks/*.rake')].each { |ext| load ext } if defined?(Rake)

# Simple, time managed events handler
#
# Author::    Igor Rzegocki (mailto:igor.rzegocki@gmail.com)
# Copyright:: Copyright (c) 2012 Igor Rzegocki
# License::   MIT License

module Expiry
  
  EXPIRY = 3600  

  class ExpiryError < Exception
  end
  
  module ClassMethods
    
    def expirable *args
      expire_condition = "`#{table_name}`.`expires_at` > ?"
      if args.last.kind_of?(Hash)
        arg_hash = args.last.symbolize_keys
        if arg_hash[:conditions].is_a?(Array)
          arg_hash[:conditions][0] = (arg_hash[:conditions].first.blank? ? '' : "(#{arg_hash[:conditions].first}) AND ") + expire_condition
          arg_hash[:conditions].push Time.now
        elsif arg_hash[:conditions].kind_of?(String)
          arg_hash[:conditions] = [(arg_hash[:conditions].blank? ? '' : "(#{arg_hash[:conditions]}) AND ") + expire_condition, Time.now]
        else
          arg_hash[:conditions] = [expire_condition, Time.now]
        end
        args[-1] = arg_hash
      else
        args.push({:conditions => [expire_condition, Time.now]})
      end
      result = find(*args)
    end
    
    def expirable?
      column_names.include?('expires_at')
    end
    
  end
  
  def expiry after = self.class::EXPIRY
    begin
      case true
      when after.kind_of?(Time)
        self.expires_at = after
      when !after
        self.expires_at = nil
      else
        self.expires_at = Time.now + after
      end
      save!
    rescue NoMethodError
      raise ExpiryError, "Table #{self.class.table_name} is incompatible with Expiry - it lacks `expires_at` column"
    end
  end
  
  def expiry_left
    self.expires_at.blank? ? nil : self.expires_at - Time.now
  end
  
  def self.included(o)
    o.extend(ClassMethods)
  end

end
