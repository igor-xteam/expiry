require 'test_helper'

class ExpiryTest < ActiveSupport::TestCase #:nodoc:
  
  def setup
    @expirator_klass = Class.new(ActiveRecord::Base)
    @expirator_klass.send(:include, Expiry)
    @expirator_klass.set_table_name 'expirators'
  end
  
  test 'Expiry module should exist' do
    assert defined?(Expiry)
  end
    
  test 'it should set default expire time' do
    expirator = @expirator_klass.new
    
    expirator.expiry
    expirator.reload
    
    assert_kind_of Time, expirator.expires_at
    assert_in_delta(Time.now + Expiry::EXPIRY, expirator.expires_at, 2.seconds)
  end
  
  test 'it should set class default expire time' do
    @expirator_klass.const_set('EXPIRY', 15.minutes)
    expirator = @expirator_klass.new
    
    expirator.expiry
    expirator.reload
    
    assert_kind_of Time, expirator.expires_at
    assert_in_delta(Time.now + 15.minutes, expirator.expires_at, 2.seconds)
  end
  
  test 'it should set custom expire time' do
    expirator = @expirator_klass.new
    
    expirator.expiry 5.minutes
    expirator.reload
    
    assert_kind_of Time, expirator.expires_at
    assert_in_delta(Time.now + 5.minutes, expirator.expires_at, 2.seconds)
  end
  
  test 'it should expire at specified time' do
    expirator = @expirator_klass.new
    
    expirator.expiry Time.at(2**31 - 1)
    expirator.reload
    
    assert_kind_of Time, expirator.expires_at
    assert_equal Time.at(2**31 - 1), expirator.expires_at
  end
  
  test 'it should fail when model does not have expired_at field' do
    @no_expirator_klass = Class.new(ActiveRecord::Base)
    @no_expirator_klass.send(:include, Expiry)
    @no_expirator_klass.set_table_name 'no_expirators'
    no_expirator = @no_expirator_klass.new
    
    assert_raises Expiry::ExpiryError do
      no_expirator.expiry
    end
  end
  
  test 'it should reset expiration when nil/false is passed' do
    expirator = @expirator_klass.new
    reset_expirator = @expirator_klass.new
    
    expirator.expiry nil
    expirator.reload
    reset_expirator.expiry 20.minutes
    reset_expirator.reload
    reset_expirator.expiry nil
    reset_expirator.reload
    
    assert_nil expirator.expires_at
    assert_nil reset_expirator.expires_at
  end
  
  test 'it should return how much time is left' do
    expirator1 = @expirator_klass.new
    expirator2 = @expirator_klass.new({:expires_at => 42.minutes.from_now})
    
    expirator1.expiry 37.minutes
    expirator1.reload
    
    assert_in_delta(37.minutes, expirator1.expiry_left, 2.second)
    assert_in_delta(42.minutes, expirator2.expiry_left, 2.second)
  end
  
  test 'it should not return left time if expiration date is not set' do
    expirator = @expirator_klass.new
    
    assert_nil expirator.expiry_left
  end
  
  test 'it should return only objects which expires' do
    @expirator_klass.create({:expires_at => nil})
    @expirator_klass.create({:expires_at => 10.minutes.ago})
    good_expirator = @expirator_klass.create({:expires_at => 10.minutes.from_now})
    
    expirator = @expirator_klass.expirable(:first)
    expirators = [
                  @expirator_klass.expirable(:all),
                  @expirator_klass.expirable(:all, :conditions => '1 = 1'),
                  @expirator_klass.expirable(:all, :conditions => ['created_at <= ?', Time.now]),
                  @expirator_klass.expirable(:all, :conditions => ''),
                  @expirator_klass.expirable(:all, :conditions => ['']),
                  @expirator_klass.expirable(:all, :select => '*')
                  ]
    
    assert_equal good_expirator.id, expirator.id
    expirators.each do |results|
      assert_equal 1, results.size
      assert_equal good_expirator.id, results.first.id
    end
  end
  
  test 'it should check if model is expirable?' do
    @no_expirator_klass = Class.new(ActiveRecord::Base)
    @no_expirator_klass.send(:include, Expiry)
    @no_expirator_klass.set_table_name 'no_expirators'
    
    assert @expirator_klass.expirable?
    assert !@no_expirator_klass.expirable?
  end
  
  test 'it should not make expires_at ambigious' do
    @expirator_klass.create({:expires_at => nil})
    @expirator_klass.create({:expires_at => 10.minutes.ago})
    good_expirator = @expirator_klass.create({:expires_at => 10.minutes.from_now})
    
    assert_nothing_raised do
      @expirator_klass.expirable(:first, :joins => "INNER JOIN `#{@expirator_klass.table_name}` `other_table_with_expires_at` ON (`#{@expirator_klass.table_name}`.`id` = `other_table_with_expires_at`.`id`)")
    end
  end
  
  test 'it should expire manually' do
    expirator = @expirator_klass.create({:expires_at => 10.minutes.from_now})
    
    expirator.expired!
    
    assert_in_delta(Time.now, expirator.expires_at, 2.seconds)
  end
  
end
