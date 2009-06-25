class Array
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
end


