require 'spec_helper'

describe Hash do
  before do
    @sample = {
      1 => {1 => 'a'},
      2 => {1 => 'b'},
      3 => {2 => 'c'},
      4 => {2 => 'd'},
      5 => {3 => 'e'},
      6 => {3 => 'f'}
    }
  end

  it "rejects even keys" do
    @sample.reject { |key, value| key % 2 == 0 }.should == {
      1 => {1 => 'a'},
      3 => {2 => 'c'},
      5 => {3 => 'e'}
    }
  end

  it "recursively rejects even keys" do
    @sample.recursively_reject { |key, value| key % 2 == 0 }.should == {
      1 => {1 => 'a'},
      3 => {},
      5 => {3 => 'e'}
    }
  end
end