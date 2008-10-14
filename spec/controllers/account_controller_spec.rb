require File.dirname(__FILE__) + "/../spec_helper"

describe AccountController do
  include Stubby
  include SpecControllerHelper

  before :each do
    scenario :site_with_a_user

    @account_path = '/account'
    @new_account_path = '/account/new'
    @verify_account_path = '/account/verify'

    @params = { :user => { 'name' => 'name',
                           'email' => 'email@email.org',
                           'login' => 'login',
                           'password' => 'password',
                           'password_confirmation' => 'password' } }
  end

  describe "GET to :new" do
    act! { request_to :get, @new_account_path }
    it_assigns :user
    it_renders_template :new
  end

  describe "POST to :create" do
    before :each do
      @user.stub!(:new_record?).and_return true
      @user.stub!(:save).and_return true
      @site.stub!(:save).and_return true
      AccountMailer.stub!(:deliver_signup_verification)
    end

    act! { request_to :post, @account_path, @params }
    it_assigns :user

    describe "given valid account params" do
      it_renders_template :verification_sent
      it_triggers_event :user_registered

      it "adds the new account to the site's accounts collection" do
        @site.users.should_receive(:build).with(@params[:user]).and_return(@user)
        act!
      end

      it "sends a validation email to the user" do
        AccountMailer.should_receive(:deliver_signup_verification)
        act!
      end
    end

    describe "given invalid account params" do
      before :each do
        @site.stub!(:save).and_return false
      end

      it_does_not_trigger_any_event
      it_renders_template :new
      it_assigns_flash_cookie :error => :not_nil
    end
  end
  
  describe "GET to :verify" do
    before :each do
      @user = User.new :name => 'name'
      controller.stub!(:current_user).and_return @user
    end
      
    act! { request_to :get, @verify_account_path }
    
    describe "given the user has been logged in from params[:token]" do
      before :each do
        @user.stub!(:verify!).and_return true
      end
      
      it_triggers_event :user_verified
      it_assigns_flash_cookie :notice => :not_nil
    end
    
    describe "given the user has not been logged in from params[:token]" do
      before :each do
        @user.stub!(:verify!).and_return false
      end
      
      it_does_not_trigger_any_event
      it_assigns_flash_cookie :error => :not_nil
    end
  end
  
  describe "DELETE to :destroy" do
    before :each do
      @user = User.new :name => 'name'
      @user.stub!(:destroy)
      @user.stub!(:frozen?).and_return true
      controller.stub!(:current_user).and_return @user
    end
    
    act! { request_to :delete, @account_path }
    it_triggers_event :user_deleted
    it_assigns_flash_cookie :notice => :not_nil
    
    it "deletes the current user account" do
      @user.should_receive(:destroy)
      act!
    end
  end
end