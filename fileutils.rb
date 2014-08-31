module FileUtils
  def self.ls *args
    list = args[0]
    opts = args[1]

    if list.class == Array
      class << list
        def to_s
          join ' '
        end
      end
    end

    res = `ls #{opts.to_s} #{list.to_s}`.split "\n"

    return res if list.class != Array

    delim = list.map do |i| i << ':' end

    indexes = delim.map do |i| i = res.index i end

    indexes.sort!

    indexes = indexes.drop 1 if indexes[0].zero?

    indexes << -1

    li = 0

    res_map = {}

    indexes.each do |i|
      path = res[li][0..res[li].length-2]

      res_map[path] = res[li+1..i-1]
      res_map[path].delete_at -1 if res_map[path][-1].length.zero?
      li = i
    end

    return res_map
  end

  def self.cp dst, src, opt
    if dst.class == Array
      raise ArgumentError if dst.count != 1

      class << src
        def to_s
          join ' '
        end
      end
    end

    if src.class == Array
      raise ArgumentError if dst.count == 0
    end

    `cp #{src.to_s} #{dst.to_s}`
  end

  def self.mv dst, src, opt
  end

  def self.rm files, opt
  end

  def self.rmdir files, opt
  end

  def self.ln dst, src, opt
  end

  def self.unlink files, opt
  end

  def self.touch files, opt
  end

end

# vim: sw=2 sts=2 ts=8:

