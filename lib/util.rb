class SortedArray < Array

	def find_index(value)
    if self.length == 0
      return 0
    elsif self.first >= value
      return 0
    elsif self.last <= value
      return self.length
    else
      start, finish = 0, self.length - 1
      loop do
        median = ((start + finish)/2).to_i
        if self[median] > value
          return median if self[median-1] < value
	        finish = median - 1
        elsif self[median] < value
          return median + 1 if self[median+1] > value
          start = median + 1
        else
          return median
        end
      end
		end
	end

	def find_exact_index(value)
    if self.length == 0
			return nil
    elsif self.first > value
      return nil
    elsif self.last < value
      return nil
		else 
      start, finish = 0, self.length - 1
      loop do
        median = ((start + finish)/2).to_i
        if self[median] > value
          return nil if self[median-1] < value
	        finish = median - 1
        elsif self[median] < value
          return nil if self[median+1] > value
          start = median + 1
        else
          return median if self[median].object_id == value.object_id
					# if we are here then we have an exact match for value but not id
					# we need to check backward and forward till we find the exact match
					newmedian = median
					while newmedian -= 1
						return newmedian if self[newmedian].object_id == value.object_id
						break if self[newmedian] != value
					end
					newmedian = median
					while newmedian += 1
						return newmedian if self[newmedian].object_id == value.object_id
						break if self[newmedian] != value
					end
					return nil
        end
      end		
		end
	end

  def insert_sorted(value)
    #move across all values
    if self.length == 0
      self << value
    elsif self.first >= value
      self.unshift value
    elsif self.last <= value
      self << value
    else
      #find the first value that is bigger than value
      start, finish = 0, self.length - 1
      loop do
        median = ((start + finish)/2).to_i
        if self[median] > value
          if self[median-1] < value
            self.insert(median, value)
            break
          end
          finish = median - 1
        elsif self[median] < value
          if self[median+1] > value
            self.insert(median + 1, value)
            break
          end
          start = median + 1
        else
          self.insert(median, value)
          break
        end
      end
    end
  end

	def remove_sorted(value)
		if index = self.find_exact_index(value)
			self.slice!(index)
		end
	end

end

if __FILE__ == $0

	class TestValue
		include Comparable

		attr_reader :value
		
		def initialize(value)
			@value = value
		end

		def <=>(other)
			self.value <=> other.value
		end

	end

	require "test/unit.rb"

	class SortedArrayTest < Test::Unit::TestCase
		def setup
		  @array = SortedArray.new
		end
		
		def test_insert
			@array.insert_sorted TestValue.new(55)
			@array.insert_sorted TestValue.new(45)
			@array.insert_sorted TestValue.new(35)
			@array.insert_sorted TestValue.new(25)
			@array.insert_sorted TestValue.new(15)
			@array.insert_sorted TestValue.new(5)
			assert_equal(5, @array.first.value)
			assert_equal(6, @array.length)
			assert_equal(55, @array.last.value)
		end

		def test_insert_duplicates
			@array.insert_sorted TestValue.new(55)
			@array.insert_sorted TestValue.new(45)
			@array.insert_sorted TestValue.new(35)
			@array.insert_sorted TestValue.new(55)
			@array.insert_sorted TestValue.new(45)
			@array.insert_sorted TestValue.new(35)
			assert_equal(35, @array.first.value)
			assert_equal(35, @array[1].value)
			assert_equal(45, @array[2].value)
			assert_equal(45, @array[3].value)
			assert_equal(6, @array.length)
		end

		def test_remove
			first = TestValue.new(35)
			second = TestValue.new(45)
			@array.insert_sorted first
			@array.insert_sorted second
			assert_equal(35, @array[0].value)
			assert_equal(2, @array.length)
			@array.remove_sorted first
			assert_equal(45, @array[0].value)
			assert_equal(1, @array.length)
		end	

		def test_remove_duplicates
			first = TestValue.new(55)
			second = TestValue.new(55)
			@array.insert_sorted first
			@array.insert_sorted second
			assert_equal(2, @array.length)
			@array.remove_sorted second
			assert_equal(first.object_id, @array[0].object_id)
			assert_equal(1, @array.length)
		end

		def test_performance
			t = Time.now
			10000.times do |i|
				@array.insert_sorted(i)
			end
			puts "\n10000 insertions in order in #{Time.now - t}"
			t = Time.now
			10000.times do |i|
				@array.remove_sorted(i)
			end
			puts "10000 removes in order in #{Time.now - t}"
			t = Time.now
			10000.downto(0) do |i|
				@array.insert_sorted(i)
			end
			puts "10000 insertions out if order in #{Time.now - t}"
			t = Time.now
			10000.downto(0) do |i|
				@array.remove_sorted(i)
			end
			puts "10000 removes out if order in #{Time.now - t}"			
		end

	end  

end
