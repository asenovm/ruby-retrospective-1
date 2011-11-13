class Song
  attr_accessor :attributes
  def initialize
    @attributes = {}
  end
  
  def name
    @attributes[:name][0]
  end

  def artist
    @attributes[:artist][0]
  end

  def genre
    @attributes[:genre][0]
  end

  def subgenre
    if not @attributes[:subgenre]
      @attributes[:subgenre]
    else
      if @attributes[:subgenre].length > 1
        @attributes[:subgenre]
      else
        @attributes[:subgenre][0]
      end
    end
  end

  def tags
    if not @attributes[:tags]
      @attributes[:tags]
    else
      if @attributes[:tags].length > 1
        @attributes[:tags]
      else
        @attributes[:tags][0]
      end
    end
  end
end

class SongParser
  attr_reader :songs
  def initialize(catalogue, tags)
    @songs = []
    catalogue.each_line { |line| @songs << (parse_song line, tags)}
  end

  private
  def parse_song(song_as_string, tags)
    song_data = song_as_string.split('.').map(&:strip)
    song = Song.new
    parse_song_name(song,song_data[0])
    parse_artist_name(song,song_data[1])
    parse_genres_and_subgenres(song,song_data[2])
    parse_tags(song,song_data[3], tags)
    song
  end

  def parse_song_name(song, song_name_as_string)
    song.attributes[:name] = [song_name_as_string]
  end

  def parse_artist_name(song, artist_name_as_string)
    song.attributes[:artist] = [artist_name_as_string]
  end

  def parse_genres_and_subgenres(song, genres_and_subgenres_as_string)
    all_genres = genres_and_subgenres_as_string.split(',').map(&:strip)
    song.attributes[:genre] = [all_genres[0]]
    if all_genres.length > 1
      song.attributes[:subgenre] = all_genres[1...all_genres.length]
    end
  end

  def parse_tags(song, tags_as_string, tags_hash)
    if not tags_as_string
      song.attributes[:tags] = []
    else
      song.attributes[:tags] = tags_as_string.split(',').map(&:strip)
    end
    tags_hash.each do |key, value|
      if key == song.artist
        song.attributes[:tags] += value
      end
    end
    attach_genre_and_subgenres_as_tags(song)
  end

  def attach_genre_and_subgenres_as_tags(song)
    song.attributes[:tags] += song.attributes[:genre].map(&:downcase)
    if song.attributes[:subgenre]
      song.attributes[:tags] += song.attributes[:subgenre].map(&:downcase)
    end
  end
end

class Collection
  def initialize(catalogue, tags)
    song_parser = SongParser.new(catalogue, tags)
    @songs = song_parser.songs
  end 
  
  def find(criteria={})
    @songs.select{ |song| is_criteria_fulfilled?(song,criteria)}
  end

  private
  def is_criteria_fulfilled?(song, criteria)
    criteria.all? { |key, value| delegate_criteria?(song,key,value) }
  end

  def delegate_criteria?(song, key, values)
    if values.kind_of? Array
      values.all? {|value| is_simple_criteria_fulfilled?(song,key,value)}
    else
      is_simple_criteria_fulfilled?(song,key,values)
    end
  end
  
  def is_simple_criteria_fulfilled?(song, key, value)
    result = false
    if key == :filter
      result = value.call(song)
    else
      if value.include?("!")
        result = (not song.attributes[key].include?(value.chop))
      else
        result = song.attributes[key].include?(value)
      end
    end
    result
  end   
end
