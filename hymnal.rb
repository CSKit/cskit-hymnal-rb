require 'net/http'
require 'nokogiri'
require 'json'

class HymnalDownloader

  BASE_URL = "christianscience.com"
  HYMN_COUNT = 462  # includes 2008 supplement

  class << self
    def download_each
      HYMN_COUNT.times do |i|
        yield i + 1, download(i + 1)
      end
    end

    def download(number)
      result = ""

      Net::HTTP.start(BASE_URL) do |http|
        resp = http.get("/concordapi/view?book=tfccs.main.hy&q=#{number}")
        result = resp.body
      end

      result
    end
  end

end

Hymn = Struct.new(:number, :title, :composer, :verses) do
  def to_hash
    { :number => number,
      :title => title,
      :composer => composer,
      :verses => verses.map(&:to_hash) }
  end
end

Verse = Struct.new(:sentences) do
  def to_hash
    sentences || []
  end
end

class HymnalSplitter
  class << self

    def parse_file(input_file)
      parse(File.read(input_file))
    end

    def parse(data)
      doc = Nokogiri::HTML(data)
      hymn_root = doc.css("div.hymn").first

      Hymn.new(
        get_number(hymn_root),
        get_title(hymn_root),
        get_composer(hymn_root),
        get_verses(hymn_root)
      )
    end

    private

    def get_number(root)
      root.attributes["data-hymn-number"].text.to_i
    end

    def get_title(root)
      root.css("div.tuneCredit div.hymnTitle").text
    end

    def get_composer(root)
      root.css("div.tuneCredit div.hymnComposer").text
    end

    def get_verses(root)
      root.css("p.verse").map do |verse_node|
        Verse.new(
          verse_node.css("span.sentence").map(&:text)
        )
      end
    end

  end
end

HymnalDownloader.download_each do |number, data|
  puts "Processing hymn #{number}"
  File.open("/Users/legrandfromage/Desktop/hymns/#{number}.json", "w+") do |f|
    f.write(HymnalSplitter.parse(data).to_hash.to_json)
  end
end
