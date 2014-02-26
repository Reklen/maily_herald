require 'spec_helper'

describe MailyHerald::SubscriptionGroup do
  before(:each) do
    @group = MailyHerald.subscription_group(:marketing)
    @entity = FactoryGirl.create :user

    @sequence = MailyHerald.sequence(:newsletters)
    @sequence.subscription_group = :marketing
    @sequence.save!
  end

  after(:each) do
    @sequence.subscription_group = nil
    @sequence.save!
    @group.update_attribute(:autosubscribe, false)
  end

  describe "Associations" do
    it {should have_many(:mailings)}
    it {should have_many(:sequences)}
    it {should have_many(:aggregated_subscriptions)}

    it "should have correct associations" do
      @sequence.subscription_group.should eq(@group)
      @group.sequences.should include(@sequence)
    end
  end

  describe "Without group autosubscribe" do
    before(:each) do
      @group.update_attribute(:autosubscribe, false)
      @group.autosubscribe.should be_false
    end

    describe "Subscribe & unsubscribe" do
      it "should handle group subscriptions" do
        MailyHerald::SequenceSubscription.count.should eq(0)
        MailyHerald::AggregatedSubscription.count.should eq(0)

        subscription = @sequence.subscription_for @entity
        subscription.should be_valid
        subscription.should_not be_a_new_record

        MailyHerald::SequenceSubscription.count.should eq(1)
        MailyHerald::AggregatedSubscription.count.should eq(1)

        subscription.should be_aggregated
        aggregated = subscription.aggregate
        aggregated.should be_a(MailyHerald::AggregatedSubscription)
        aggregated.entity.should eq(@entity)
        aggregated.group.should eq(@sequence.subscription_group)

        subscription.should_not be_active

        @sequence.reload
        subscription = @sequence.subscription_for @entity
        MailyHerald::SequenceSubscription.count.should eq(1)
        MailyHerald::AggregatedSubscription.count.should eq(1)
      end

      it "should be able to activate/deactivate" do
        subscription = @sequence.subscription_for @entity
        aggregated = subscription.aggregate

        subscription.should be_valid
        subscription.should_not be_a_new_record
        subscription.should_not be_active

        aggregated.should be_valid
        aggregated.should_not be_a_new_record
        aggregated.should_not be_active

        subscription.should be_aggregated
        subscription.activate!

        aggregated = subscription.aggregate

        subscription.should be_active
        aggregated.should be_active

        aggregated.deactivate!

        subscription.should_not be_active
        aggregated.should_not be_active
      end
    end
  end

  describe "With group autosubscribe" do
    before(:each) do
      @group.update_attribute(:autosubscribe, true)
      @group.autosubscribe.should be_true
    end

    describe "Subscribe & unsubscribe" do
      it "should handle group subscriptions" do
        MailyHerald::SequenceSubscription.count.should eq(0)
        MailyHerald::AggregatedSubscription.count.should eq(0)

        subscription = @sequence.subscription_for @entity
        subscription.should be_valid
        subscription.should_not be_a_new_record

        MailyHerald::SequenceSubscription.count.should eq(1)
        MailyHerald::AggregatedSubscription.count.should eq(1)

        subscription.should be_aggregated
        aggregated = subscription.aggregate
        aggregated.should be_a(MailyHerald::AggregatedSubscription)
        aggregated.entity.should eq(@entity)
        aggregated.group.should eq(@sequence.subscription_group)

        subscription.should be_active

        @sequence.reload
        subscription = @sequence.subscription_for @entity
        MailyHerald::SequenceSubscription.count.should eq(1)
        MailyHerald::AggregatedSubscription.count.should eq(1)
      end

      it "should be able to activate/deactivate" do
        subscription = @sequence.subscription_for @entity
        aggregated = subscription.aggregate

        subscription.should be_valid
        subscription.should_not be_a_new_record
        subscription.should be_active

        aggregated.should be_valid
        aggregated.should_not be_a_new_record
        aggregated.should be_active

        subscription.should be_aggregated
        subscription.deactivate!

        aggregated = subscription.aggregate

        subscription.should_not be_active
        aggregated.should_not be_active

        aggregated.activate!

        subscription.should be_active
        aggregated.should be_active
      end
    end
  end

  describe "Accessing subscription via group" do
    before(:each) do
      @group.update_attribute(:autosubscribe, true)
      @group.autosubscribe.should be_true
    end

    it "should create aggreggated subscription" do
      aggregate = @group.aggregate_for @entity
      aggregate.should be_active
      aggregate.update_attribute(:active, false)

      @sequence.subscription_for(@entity).should_not be_active
    end

    it "should disregard dispatch autosubscribe" do
      @sequence.update_attribute(:autosubscribe, true)

      aggregate = @group.aggregate_for @entity
      aggregate.should be_active
      aggregate.update_attribute(:active, false)

      @sequence.subscription_for(@entity).should_not be_active
    end
  end
end
