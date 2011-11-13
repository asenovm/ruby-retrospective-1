class Array
  def to_hash
    result = {}
    each do |item|
      result[item[0]] = item[1]
    end
    result
  end

  def index_by(&block)
    map(&block).zip(self).to_hash
  end

  def subarray_count(subarray)
    each_cons(subarray.length).count(subarray)
  end

  def occurences_count
    Hash.new { |hash, key| 0 }.tap do |result|
      each { |item| result[item] += 1 }
    end
  end

end
